import os
import sys
import json
import time
import argparse
from typing import List, Dict, Tuple
from collections import Counter

import torch
import torch.nn as nn
from torch.utils.data import Dataset, DataLoader
from transformers import AutoTokenizer, AutoModelForSequenceClassification, get_cosine_schedule_with_warmup

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')


class ShifaaConsultationDataset(Dataset):
    def __init__(self, data_file: str, tokenizer, max_length: int = 256, max_samples: int = None):
        self.tokenizer = tokenizer
        self.max_length = max_length
        self.samples = []

        with open(data_file, 'r', encoding='utf-8') as f:
            for line in f:
                if not line.strip():
                    continue
                record = json.loads(line)
                self.samples.append((record['text'], record['label_id']))
                if max_samples and len(self.samples) >= max_samples:
                    break

    def __len__(self):
        return len(self.samples)

    def __getitem__(self, idx):
        text, label = self.samples[idx]
        encoding = self.tokenizer(
            text,
            truncation=True,
            max_length=self.max_length,
            padding='max_length',
            return_tensors='pt'
        )
        return {
            'input_ids': encoding['input_ids'].squeeze(0),
            'attention_mask': encoding['attention_mask'].squeeze(0),
            'label': torch.tensor(label, dtype=torch.long)
        }


def compute_metrics(preds: List[int], targets: List[int], id2label: Dict[int, str]) -> Dict:
    """Computes Accuracy, Macro-F1, and per-class Precision/Recall without external dependencies."""
    total = len(targets)
    correct = sum(1 for p, t in zip(preds, targets) if p == t)
    acc = correct / total if total > 0 else 0.0

    all_labels = sorted(list(id2label.keys()))
    per_class = {}
    f1_list = []

    for l_id in all_labels:
        label_name = id2label[l_id]
        tp = sum(1 for p, t in zip(preds, targets) if p == l_id and t == l_id)
        fp = sum(1 for p, t in zip(preds, targets) if p == l_id and t != l_id)
        fn = sum(1 for p, t in zip(preds, targets) if p != l_id and t == l_id)

        precision = tp / (tp + fp) if (tp + fp) > 0 else 0.0
        recall = tp / (tp + fn) if (tp + fn) > 0 else 0.0
        f1 = (2 * precision * recall) / (precision + recall) if (precision + recall) > 0 else 0.0

        support = sum(1 for t in targets if t == l_id)
        per_class[label_name] = {
            'precision': round(precision, 4),
            'recall': round(recall, 4),
            'f1': round(f1, 4),
            'support': support
        }
        if support > 0:
            f1_list.append(f1)

    macro_f1 = sum(f1_list) / len(f1_list) if f1_list else 0.0

    return {
        'accuracy': round(acc, 4),
        'macro_f1': round(macro_f1, 4),
        'per_class': per_class
    }


def train_model(
    data_dir: str,
    output_dir: str,
    model_name: str = 'UBC-NLP/MARBERTv2',
    epochs: int = 4,
    batch_size: int = 8,
    lr: float = 2.5e-5,
    max_len: int = 256,
    max_samples: int = None
):
    print("=" * 65)
    print(f"🚀 Fine-Tuning MARBERTv2 Clinical Classifier ({model_name})")
    print(f"⚙️ Config: max_len={max_len}, epochs={epochs}, lr={lr}, batch_size={batch_size}")
    print("=" * 65)

    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f"Hardware Acceleration: {device.type.upper()}")
    if device.type == 'cuda':
        print(f"GPU: {torch.cuda.get_device_name(0)}")

    # Load label mapping
    mapping_file = os.path.join(data_dir, 'label_mapping.json')
    if not os.path.exists(mapping_file):
        raise FileNotFoundError(f"Label mapping not found at {mapping_file}. Run prepare_shifaa_data.py first.")

    with open(mapping_file, 'r', encoding='utf-8') as f:
        meta = json.load(f)

    label2id = meta['label2id']
    id2label = {int(k) if isinstance(k, str) and k.isdigit() else v: (v if isinstance(k, int) else k) for k, v in meta['id2label'].items()}
    id2label = {int(k): v for k, v in meta['id2label'].items()} if all(str(k).isdigit() for k in meta['id2label'].keys()) else {v: k for k, v in label2id.items()}
    num_labels = len(label2id)

    print(f"Number of Clinical Diagnostic Classes: {num_labels}")
    for k, v in label2id.items():
        print(f" - [{v}] {k}")

    # Load Tokenizer & Model
    print(f"\nLoading Tokenizer: {model_name}...")
    tokenizer = AutoTokenizer.from_pretrained(model_name)

    print(f"Initializing AutoModelForSequenceClassification (num_labels={num_labels})...")
    model = AutoModelForSequenceClassification.from_pretrained(
        model_name,
        num_labels=num_labels,
        id2label=id2label,
        label2id=label2id
    )
    model.to(device)

    # Datasets with max_len=256
    train_file = os.path.join(data_dir, 'train_shifaa.jsonl')
    test_file = os.path.join(data_dir, 'test_shifaa.jsonl')

    print(f"\nLoading Training Dataset: {train_file} (max_len={max_len})...")
    train_dataset = ShifaaConsultationDataset(train_file, tokenizer, max_length=max_len, max_samples=max_samples)
    print(f"Loading Testing Dataset (20%): {test_file} (max_len={max_len})...")
    test_dataset = ShifaaConsultationDataset(test_file, tokenizer, max_length=max_len, max_samples=max_samples // 4 if max_samples else None)

    print(f"Train samples: {len(train_dataset)} | Test samples: {len(test_dataset)}")

    train_loader = DataLoader(train_dataset, batch_size=batch_size, shuffle=True)
    test_loader = DataLoader(test_dataset, batch_size=batch_size, shuffle=False)

    # Balanced Class Weights for Clinical Category Imbalance
    train_labels = [s[1] for s in train_dataset.samples]
    label_counts = Counter(train_labels)
    n_samples = len(train_labels)
    class_weights = [
        n_samples / (num_labels * max(1, label_counts.get(i, 1)))
        for i in range(num_labels)
    ]
    weights_tensor = torch.tensor(class_weights, dtype=torch.float).to(device)
    loss_fn = nn.CrossEntropyLoss(weight=weights_tensor)

    # Optimizer & Cosine Annealing Scheduler with Warmup
    optimizer = torch.optim.AdamW(model.parameters(), lr=lr, weight_decay=0.01)
    total_steps = len(train_loader) * epochs
    warmup_steps = int(total_steps * 0.1)
    scheduler = get_cosine_schedule_with_warmup(optimizer, num_warmup_steps=warmup_steps, num_training_steps=total_steps)

    best_macro_f1 = 0.0
    best_top1_acc = 0.0
    best_top2_acc = 0.0
    os.makedirs(output_dir, exist_ok=True)

    print("\n" + "=" * 65)
    print(f"🏋️ Starting Training ({epochs} Epochs | Batch Size {batch_size} | Cosine Warmup)")
    print("=" * 65)

    training_history = []

    for epoch in range(1, epochs + 1):
        model.train()
        total_train_loss = 0.0
        start_time = time.time()

        for step, batch in enumerate(train_loader):
            input_ids = batch['input_ids'].to(device)
            attention_mask = batch['attention_mask'].to(device)
            labels = batch['label'].to(device)

            optimizer.zero_grad()
            outputs = model(input_ids=input_ids, attention_mask=attention_mask)
            logits = outputs.logits
            loss = loss_fn(logits, labels)

            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
            optimizer.step()
            scheduler.step()

            total_train_loss += loss.item()

            if (step + 1) % max(1, len(train_loader) // 5) == 0 or (step + 1) == len(train_loader):
                avg_step_loss = total_train_loss / (step + 1)
                print(f"Epoch {epoch}/{epochs} | Step {step+1}/{len(train_loader)} | Loss: {avg_step_loss:.4f}")

        avg_train_loss = total_train_loss / max(1, len(train_loader))
        epoch_time = time.time() - start_time

        # Evaluation on 20% Test Set (Top-1 and Top-2 Comorbidity Accuracy)
        model.eval()
        val_preds = []
        val_targets = []
        top2_hits = 0
        total_val_loss = 0.0

        with torch.no_grad():
            for batch in test_loader:
                input_ids = batch['input_ids'].to(device)
                attention_mask = batch['attention_mask'].to(device)
                labels = batch['label'].to(device)

                outputs = model(input_ids=input_ids, attention_mask=attention_mask)
                loss = loss_fn(outputs.logits, labels)
                total_val_loss += loss.item()

                preds = torch.argmax(outputs.logits, dim=1).cpu().tolist()
                val_preds.extend(preds)
                val_targets.extend(labels.cpu().tolist())

                top2_indices = torch.topk(outputs.logits, k=2, dim=1).indices.cpu().tolist()
                for t, p2 in zip(labels.cpu().tolist(), top2_indices):
                    if t in p2:
                        top2_hits += 1

        avg_val_loss = total_val_loss / max(1, len(test_loader))
        metrics = compute_metrics(val_preds, val_targets, id2label)
        top2_acc = top2_hits / len(val_targets) if val_targets else 0.0
        metrics['top2_accuracy'] = round(top2_acc, 4)

        print(f"\n📊 Epoch {epoch} Evaluation (20% Test Set, {len(val_targets)} samples):")
        print(f" - Train Loss: {avg_train_loss:.4f} | Test Loss: {avg_val_loss:.4f}")
        print(f" - Top-1 Accuracy: {metrics['accuracy']*100:.2f}% | Top-2 Comorbidity: {top2_acc*100:.2f}% | Macro F1: {metrics['macro_f1']*100:.2f}%")
        print(f" - Epoch Duration: {epoch_time:.1f}s")

        training_history.append({
            'epoch': epoch,
            'train_loss': round(avg_train_loss, 4),
            'val_loss': round(avg_val_loss, 4),
            'accuracy': metrics['accuracy'],
            'top2_accuracy': metrics['top2_accuracy'],
            'macro_f1': metrics['macro_f1']
        })

        # Save checkpoint if best macro F1 or Top-1 Accuracy
        if metrics['macro_f1'] >= best_macro_f1:
            best_macro_f1 = metrics['macro_f1']
            best_top1_acc = metrics['accuracy']
            best_top2_acc = top2_acc
            print(f"⭐ New Best Model! Saving checkpoint to {output_dir}...")
            model.save_pretrained(output_dir)
            tokenizer.save_pretrained(output_dir)

    # Save final report and metrics
    metrics_file = os.path.join(output_dir, 'training_metrics.json')
    with open(metrics_file, 'w', encoding='utf-8') as f:
        json.dump({
            'best_macro_f1': best_macro_f1,
            'best_top1_accuracy': best_top1_acc,
            'best_top2_comorbidity_accuracy': best_top2_acc,
            'final_metrics': metrics,
            'training_history': training_history,
            'model_name': model_name,
            'num_labels': num_labels,
            'max_len': max_len
        }, f, ensure_ascii=False, indent=2)

    # Print final summary table
    print("\n" + "=" * 65)
    print("🏆 Training Complete! Final Test Set Evaluation Per-Class:")
    print("=" * 65)
    print(f"{'Category':22} | {'Precision':10} | {'Recall':10} | {'F1-Score':10} | {'Support':8}")
    print("-" * 65)
    for cat, data in metrics['per_class'].items():
        print(f"{cat:22} | {data['precision']*100:9.1f}% | {data['recall']*100:9.1f}% | {data['f1']*100:9.1f}% | {data['support']:8}")
    print("-" * 65)
    print(f"Overall Top-1 Accuracy: {metrics['accuracy']*100:.2f}% | Top-2 Comorbidity: {metrics['top2_accuracy']*100:.2f}% | Macro F1: {metrics['macro_f1']*100:.2f}%")
    print(f"Model saved to: {output_dir}")
    print("=" * 65)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Train MARBERTv2 Diagnostic Sequence Classifier on Shifaa Consultations")
    parser.add_argument('--data-dir', type=str, default='backend/ai_engine/training/data')
    parser.add_argument('--output-dir', type=str, default='backend/ai_engine/trained_models/marbert_classifier')
    parser.add_argument('--model-name', type=str, default='UBC-NLP/MARBERTv2')
    parser.add_argument('--epochs', type=int, default=4)
    parser.add_argument('--batch-size', type=int, default=8)
    parser.add_argument('--lr', type=float, default=2.5e-5)
    parser.add_argument('--max-len', type=int, default=256)
    parser.add_argument('--max-samples', type=int, default=None, help="Limit samples for quick test")
    args = parser.parse_args()

    # Resolve relative paths
    base_dir = os.path.dirname(__file__)
    data_dir = args.data_dir if os.path.isabs(args.data_dir) else os.path.abspath(os.path.join(base_dir, 'data'))
    out_dir = args.output_dir if os.path.isabs(args.output_dir) else os.path.abspath(os.path.join(base_dir, '../trained_models/marbert_classifier'))

    train_model(
        data_dir=data_dir,
        output_dir=out_dir,
        model_name=args.model_name,
        epochs=args.epochs,
        batch_size=args.batch_size,
        lr=args.lr,
        max_len=args.max_len,
        max_samples=args.max_samples
    )
