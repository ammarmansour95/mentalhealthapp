import os
import sys
import csv
import io
import json
import random
import re
import argparse
import requests
from typing import Dict, List, Tuple
from collections import Counter

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

# Core clinical categories aligning with the mental health platform
CATEGORY_MAPPING = {
    'DEPRESSION': {
        'keywords': ['اكتئاب', 'حزن', 'كآبة', 'يأس', 'فقدان الشغف', 'إحباط'],
        'label_ar': 'أعراض المزاج الاكتئابي والحزن (Depressive Symptoms)',
        'specialty': 'CLINICAL_PSYCHOLOGY'
    },
    'ANXIETY': {
        'keywords': ['قلق', 'توتر', 'تفكير زائد', 'خوف مستمر', 'عصبية', 'تشتت'],
        'label_ar': 'أعراض القلق العام والتوتر (Generalized Anxiety)',
        'specialty': 'CBT_SPECIALIST'
    },
    'PANIC': {
        'keywords': ['مخاوف', 'هلع', 'رهاب', 'نوبة هلع', 'فزع', 'خفقان'],
        'label_ar': 'نوبات الهلع والمخاوف والرهاب (Panic & Phobia)',
        'specialty': 'PSYCHIATRY'
    },
    'SLEEP_DISRUPTION': {
        'keywords': ['نوم', 'أرق', 'كوابيس', 'سهر', 'استيقاظ متكرر', 'أحلام'],
        'label_ar': 'اضطرابات جودة النوم والأرق (Sleep Disruption)',
        'specialty': 'CLINICAL_PSYCHOLOGY'
    },
    'OBSESSIONS_OCD': {
        'keywords': ['وسواس', 'وساوس', 'قهري', 'شكوك', 'أفكار ملحة'],
        'label_ar': 'الوسواس القهري والأفكار المتسلطة (OCD & Obsessions)',
        'specialty': 'PSYCHIATRY'
    },
    'TRAUMA_PTSD': {
        'keywords': ['صدمة', 'حادث', 'فاجعة', 'كرب', 'ذكريات مؤلمة'],
        'label_ar': 'مؤشرات الصدمة النفسية والذكريات الضاغطة (Trauma & PTSD)',
        'specialty': 'TRAUMA_PTSD'
    },
    'FAMILY_CONFLICTS': {
        'keywords': ['أسرة', 'عائلة', 'زوج', 'زوجة', 'طلاق', 'خلافات أسرية'],
        'label_ar': 'الضغوطات والخلافات الأسرية (Family Dynamics)',
        'specialty': 'CLINICAL_PSYCHOLOGY'
    },
    'BURNOUT_STRESS': {
        'keywords': ['إجهاد', 'ضغط عمل', 'دراسة', 'احتراق', 'إنهاك', 'تطوير الذات'],
        'label_ar': 'الإجهاد النفسي والضغوط الحياتية (Burnout & Stress)',
        'specialty': 'CBT_SPECIALIST'
    }
}

# The 7 published CSV files comprising the 35,648 Shifaa consultations
SHIFAA_FILES = [
    'Behavioral_Psychological_Conditions.csv',
    'Childhood_Psychological_Problems.csv',
    'Neuropsychological_Conditions.csv',
    'Other_Psychological_and_Behavioral_Issues.csv',
    'Personality_and_Self_Development.csv',
    'Psychological_Issues_and_Guidance.csv',
    'Psychotic_Disorders.csv'
]

HF_BASE_URL = "https://huggingface.co/datasets/Ahmed-Selem/Shifaa_Arabic_Mental_Health_Consultations/resolve/main/"


def clean_arabic_text(text: str) -> str:
    """Normalizes whitespace, removes diacritics, and strips standard intro/outro boilerplate."""
    if not text:
        return ""
    # Strip common boilerplate phrases
    text = re.sub(r'^(السلام عليكم ورحمة الله وبركاته|مرحبا|تحية طيبة وبعد[،,:]?)\s*', '', text.strip(), flags=re.IGNORECASE)
    text = re.sub(r'(وجزاكم الله خيرا|وشكرا لكم|أفيدوني جزاكم الله خيرا|مع خالص الشكر)[.!]?\s*$', '', text.strip(), flags=re.IGNORECASE)
    # Remove tashkeel / diacritics
    text = re.sub(r'[\u064B-\u0652\u0640]', '', text)
    # Normalize multiple whitespace / newlines
    text = re.sub(r'\s+', ' ', text)
    return text.strip()


def map_diagnosis_to_category(hierarchical_diag: str, text_content: str) -> str:
    """Maps the Hierarchical Diagnosis and consultation text to one of the 8 DSM-5 categories."""
    diag = hierarchical_diag.lower() if hierarchical_diag else ""
    text_lower = text_content.lower() if text_content else ""
    
    # Priority 1: Direct match on Hierarchical Diagnosis string
    if any(kw in diag for kw in ['اكتئاب', 'حزن', 'كآبة']):
        return 'DEPRESSION'
    if any(kw in diag for kw in ['هلع', 'مخاوف', 'رهاب', 'فزع']):
        return 'PANIC'
    if any(kw in diag for kw in ['نوم', 'أرق', 'كابوس']):
        return 'SLEEP_DISRUPTION'
    if any(kw in diag for kw in ['وسواس', 'قهري']):
        return 'OBSESSIONS_OCD'
    if any(kw in diag for kw in ['قلق', 'توتر']):
        return 'ANXIETY'
    if any(kw in diag for kw in ['صدم', 'كرب']):
        return 'TRAUMA_PTSD'
    if any(kw in diag for kw in ['أسر', 'عائل', 'زوج']):
        return 'FAMILY_CONFLICTS'

    # Priority 2: Keyword density in the patient's text
    scores = {}
    for cat, meta in CATEGORY_MAPPING.items():
        score = sum(1 for kw in meta['keywords'] if kw in text_lower or kw in diag)
        scores[cat] = score

    top_cat, top_score = max(scores.items(), key=lambda x: x[1])
    if top_score > 0:
        return top_cat
    
    return 'BURNOUT_STRESS'


def download_and_process_shifaa(max_samples_per_file: int = None) -> List[Dict]:
    """Downloads Shifaa CSVs from Hugging Face, cleans rows, and labels them."""
    all_consultations = []
    print("=" * 60)
    print("📥 Starting Download of Shifaa Arabic Consultations Dataset")
    print("=" * 60)

    for filename in SHIFAA_FILES:
        url = HF_BASE_URL + filename
        print(f"Downloading {filename}...")
        try:
            r = requests.get(url, timeout=45)
            r.raise_for_status()
            content = r.content.decode('utf-8', errors='ignore')
            reader = csv.DictReader(io.StringIO(content))
            
            count = 0
            for row in reader:
                title = clean_arabic_text(row.get('Question Title', ''))
                question = clean_arabic_text(row.get('Question', ''))
                answer = clean_arabic_text(row.get('Answer', ''))
                diag = row.get('Hierarchical Diagnosis', '')
                
                # Minimum viable consultation length
                if len(question) < 20:
                    continue

                # Enhanced clinical anchor formatting for transformer attention layers
                full_text = f"استشارة سريرية: {title} | تفاصيل شكوى المريض: {question}" if title else question
                category = map_diagnosis_to_category(diag, full_text)

                all_consultations.append({
                    'text': full_text,
                    'title': title,
                    'doctor_answer': answer,
                    'original_diagnosis': diag,
                    'category': category
                })
                count += 1
                if max_samples_per_file and count >= max_samples_per_file:
                    break

            print(f" -> Processed {count} consultations from {filename}")
        except Exception as e:
            print(f"❌ Error downloading {filename}: {e}")

    return all_consultations


def split_and_save_dataset(consultations: List[Dict], output_dir: str, train_ratio: float = 0.8):
    """Performs stratified 80/20 train/test split and writes JSONL files."""
    os.makedirs(output_dir, exist_ok=True)
    random.seed(42)
    random.shuffle(consultations)

    # Group by category for stratified sampling
    by_category = {}
    for item in consultations:
        cat = item['category']
        by_category.setdefault(cat, []).append(item)

    train_data = []
    test_data = []

    for cat, items in by_category.items():
        random.shuffle(items)
        split_idx = int(len(items) * train_ratio)
        train_data.extend(items[:split_idx])
        test_data.extend(items[split_idx:])

    random.shuffle(train_data)
    random.shuffle(test_data)

    # Label encoding
    categories = sorted(list(CATEGORY_MAPPING.keys()))
    label2id = {cat: idx for idx, cat in enumerate(categories)}
    id2label = {idx: cat for idx, cat in enumerate(categories)}

    # Save mapping metadata
    label_metadata = {
        'categories': categories,
        'label2id': label2id,
        'id2label': id2label,
        'category_details': CATEGORY_MAPPING
    }
    with open(os.path.join(output_dir, 'label_mapping.json'), 'w', encoding='utf-8') as f:
        json.dump(label_metadata, f, ensure_ascii=False, indent=2)

    # Write train JSONL
    train_file = os.path.join(output_dir, 'train_shifaa.jsonl')
    with open(train_file, 'w', encoding='utf-8') as f:
        for item in train_data:
            record = {
                'text': item['text'],
                'label': item['category'],
                'label_id': label2id[item['category']],
                'summary_target': item['title'] or item['text'][:120],
                'doctor_answer': item['doctor_answer'][:300]
            }
            f.write(json.dumps(record, ensure_ascii=False) + '\n')

    # Write test JSONL
    test_file = os.path.join(output_dir, 'test_shifaa.jsonl')
    with open(test_file, 'w', encoding='utf-8') as f:
        for item in test_data:
            record = {
                'text': item['text'],
                'label': item['category'],
                'label_id': label2id[item['category']],
                'summary_target': item['title'] or item['text'][:120],
                'doctor_answer': item['doctor_answer'][:300]
            }
            f.write(json.dumps(record, ensure_ascii=False) + '\n')

    print("\n" + "=" * 60)
    print("✅ Dataset Stratified 80/20 Split Complete!")
    print("=" * 60)
    print(f"Total Consultations: {len(consultations)}")
    print(f"Train Set (80%):    {len(train_data)} records -> {train_file}")
    print(f"Test Set (20%):     {len(test_data)} records -> {test_file}")
    print("\nCategory Distribution in Train Set:")
    train_dist = Counter(item['category'] for item in train_data)
    for cat, count in train_dist.most_common():
        pct = (count / len(train_data)) * 100
        print(f" - {cat:20}: {count:5} ({pct:.1f}%) | {CATEGORY_MAPPING[cat]['label_ar'][:30]}...")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Prepare Shifaa Arabic Mental Health Dataset for AraBERT/AraBART")
    parser.add_argument('--max-per-file', type=int, default=None, help="Limit samples per file for quick testing")
    parser.add_argument('--output-dir', type=str, default='backend/ai_engine/training/data', help="Output directory")
    args = parser.parse_args()

    # Resolve output dir relative to workspace
    base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), 'data'))
    out_dir = args.output_dir if args.output_dir != 'backend/ai_engine/training/data' else base_dir

    consultations = download_and_process_shifaa(max_samples_per_file=args.max_per_file)
    split_and_save_dataset(consultations, out_dir, train_ratio=0.8)
