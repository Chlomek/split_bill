# Split Bill 🧾

Moderní Flutter aplikace pro snadné rozdělení účtů a vyrovnání dluhů mezi přáteli a kolegy. Vyfoťte účtenku, přiřaďte položky jednotlivým lidem a nechte aplikaci automaticky přepočítat dluhy a vygenerovat platební QR kód.

---

## ✨ Klíčové funkce

- 📸 **Skenování a oříznutí účtenky**: Automatická detekce okrajů účtenky a narovnání perspektivy (Google ML Kit na Androidu a Apple VisionKit na iOS).
- 🧠 **Vyměnitelná OCR architektura**:
  - **Cloud AI Vision**: Vysoce přesné strukturované načtení položek, množství a cen přes Supabase Edge Function (Gemini / OpenAI).
  - **Lokální ML Kit OCR**: Rychlé offline rozpoznávání textu bez nákladů na API.
  - **Tier-aware Quota**: Bezplatní uživatelé mají k dispozici omezený počet AI skenů s automatickým přechodem na ML Kit, předplatitelé mají neomezené AI skenování.
- 👥 **Správa skupin a virtuálních členů**: Podpora pro registrované uživatele i virtuální přátele (bez nutnosti registrace všech účastníků).
- 🔗 **Deep linky**: Pozvánky do skupin přes odkaz (`/invite/:code`).
- ⚖️ **Zjednodušení dluhů (Debt Simplification)**: Greedy algoritmus minimalizující počet převodů mezi členy.
- 💳 **QR Platba**: Okamžité vygenerování standardního českého bankovního QR kódu (**SPAYD**) i evropského **SEPA EPC QR**.
- 📊 **Export do CSV**: Export přehledů výdajů a vyrovnání do CSV souboru se sdílením.
- 💎 **Freemium model**: 2 skupiny zdarma, neomezené skupiny a exporty pro platící uživatele (RevenueCat).

---

## 🛠️ Použité technologie

- **Framework**: [Flutter](https://flutter.dev) (Dart 3.x)
- **State Management**: [Riverpod 2.x](https://riverpod.dev) (`flutter_riverpod`, `riverpod_annotation`)
- **Backend & Auth**: [Supabase](https://supabase.com) (PostgreSQL, Auth, Edge Functions, Storage)
- **Skenování & OCR**: `cunning_document_scanner`, `google_mlkit_text_recognition`
- **Navigace**: `go_router`
- **Generování QR**: `qr_flutter`
- **Předplatné**: `purchases_flutter` (RevenueCat)
- **Správa prostředí**: `flutter_dotenv`

---

## 📁 Struktura projektu

```
lib/
├── app.dart                          # Kořenový widget, konfigurace témat a lokalizace
├── main.dart                         # Vstupní bod, inicializace Env a Supabase
├── core/
│   ├── config/                       # Konfigurace prostředí (.env), Supabase a téma
│   ├── constants/                    # Konstanty (freemium limity, měny)
│   ├── errors/                       # Doménové výjimky a chyby
│   ├── routing/                      # GoRouter definice a deep link handling
│   ├── services/                     # Skenování, QR platba, CSV export, Deep linky
│   └── utils/                        # Formátování měn, algoritmus zjednodušení dluhů
└── features/
    ├── auth/                         # Přihlášení, registrace, uživatelský profil
    ├── groups/                       # Skupiny, členové, přehled zůstatků
    ├── expenses/                     # Výdaje a položkové rozúčtování
    ├── receipt_scan/                 # Swappable OCR, přiřazení položek uživatelům
    ├── settlements/                  # Přehled vyrovnání a SPAYD QR platba
    └── premium/                      # Správa předplatného a paywall
```

---

## 🚀 Jak začít

### 1. Klonování a instalace závislostí
```bash
git clone https://github.com/Chlomek/split_bill.git
cd split_bill
flutter pub get
```

### 2. Konfigurace `.env`
Zkopírujte šablonu `.env.example` do nového souboru `.env`:
```bash
cp .env.example .env
```
Doplňte své přihlašovací údaje pro Supabase a případně RevenueCat:
```env
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
APP_DOMAIN=splitbill.app
```

### 3. Spuštění aplikace
```bash
# Spuštění testů
flutter test

# Spuštění statické analýzy
flutter analyze

# Spuštění aplikace na zařízení nebo emulátoru
flutter run
```
