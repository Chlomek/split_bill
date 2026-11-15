# Split Bill — Kompletní specifikace a přehled funkcí

Tento dokument shrnuje veškeré dohodnuté funkce, architekturu, uživatelské toky a technická rozhodnutí pro aplikaci **Split Bill**.

---

## 📌 1. Základní vize a filozofie produktu

**Split Bill** je moderní mobilní aplikace ve Flutteru pro rychlé a bezstarostné rozdělení účtů v restauracích, na výletech a mezi spolubydlícími.
- **Fokus na jednoduchost**: Žádné zbytečné proklikávání ani složité účetní formuláře.
- **Odstranění trapných momentů**: Každý hned přesně vidí, kdo komu kolik dluží.
- **Okamžité vyrovnání**: Integrovaná česká **QR Platba (SPAYD)** přímo v aplikaci pro platbu na jedno kliknutí v bankovnictví.
- **Flexibilita**: Funguje jak s automatickým skenerem účtenek, tak s rychlým ručním zadáváním i pro lidi, kteří aplikaci ještě nemají staženou.

---

## 📱 2. Architektura obrazovek (3 hlavní obrazovky)

Aplikace je navržena jako přímočarý 3-krokový systém:

```
[1. Moje skupiny] ──(Klepnutí na skupinu)──> [2. Detail skupiny & Vyrovnání] ──(Skenovat / Zadat)──> [3. Přiřazení položek]
```

### 1️⃣ Obrazovka: Moje skupiny (`/`)
- **Žádné rozbalovací menu (dropdown)**: Všechny skupiny jsou přehledně zobrazeny v seznamu karet.
- **Zůstatek na první pohled**: Každá karta skupiny jasně ukazuje osobní stav přihlášeného uživatele v dané partě:
  - `Dluží vám: +200 Kč` (zelená)
  - `Dlužíte: -450 Kč` (červená)
  - `Vyrovnáno: 0 Kč` (šedá)
- **Akce**:
  - `[+ Vytvořit novou skupinu]`
  - `[Připojit se kódem pozvánky]`
  - Otevření profilu a nastavení vlastního IBANu.

### 2️⃣ Obrazovka: Detail skupiny & Vyrovnání (`/group/:id`)
*Sloučený hub pro celou skupinu spojující přehled zůstatků, plateb i historii.*
- **Sekce Přehled vyrovnání (Zjednodušený dluh)**:
  - Algoritmus minimalizace převodů zobrazuje přímé platby (např. *Pepa ➔ Kája: 200 Kč*).
  - Tlačítko **`[📱 QR Platba]`**: Přímo na obrazovce otevře český SPAYD QR kód vygenerovaný z IBANu věřitele.
  - Tlačítko **`[Označit za zaplacené ✓]`**: Okamžitě aktualizuje zůstatky skupiny.
- **Sekce Zůstatky všech členů**:
  - Přehled všech účastníků (včetně virtuálních členů bez účtu).
  - Tlačítko **`[+ Přidat člena bez účtu]`**.
- **Sekce Historie výdajů**:
  - Seznam dřívějších účtenek a ručních plateb.
- **Spodní lišta akcí (Dual Action Bar)**:
  - **`[📷 Vyfotit účtenku]`**: Spustí skener s automatickým oříznutím.
  - **`[✏️ Zadat ručně]`**: Otevře rychlý formulář pro zadání výdaje bez účtenky.
- **Horní lišta**:
  - Sdílení pozvánky do skupiny (kód / deep link).
  - Export historie do CSV (prémiová funkce).

### 3️⃣ Obrazovka: Přiřazení položek z účtenky (`/assign-items`)
- Seznam jednotlivých položek načtených z účtenky s cenami a počtem kusů.
- **Přiřazovací čipy**: Kliknutím na jména přiřadíte, kdo co jedl či pil (např. *Mléko 20 Kč ➔ Pepa & Kája*).
- **Rovnoměrný přepočet**: Cena položky se automaticky rozdělí mezi vybrané osoby (např. 10 Kč / os).
- **Detekce dýška a rozdílů**:
  - Pokud součet položek neodpovídá celkové částce na účtence (spropitné, servis, zaokrouhlení), aplikace rozdíl zvýrazní v informačním panelu a automaticky poměrně rozpočítá mezi účastníky.
- **Možnost úprav**: Tlačítko `[+]` pro ruční přidání položky a možnost smazat chybně načtené řádky.
- **Kdo platil**: Výběr člena, který účet uhradil, a potvrzovací tlačítko pro uložení.

---

## 📸 3. Skenování a OCR architektura

### Snímání dokumentu
- Knihovna: `cunning_document_scanner`.
- **Nativní detekce okrajů**: Automatické narovnání perspektivy a oříznutí pozadí stolu (využívá Google ML Kit Document Scanner na Androidu a Apple VisionKit na iOS).
- Možnost vybrat fotku z galerie zařízení.
- **Demo režim**: Tlačítko pro načtení ukázkové účtenky pro rychlé testování bez fyzického papíru.

### Vyměnitelná OCR architektura (`ReceiptScannerService`)
Aplikace má abstraktní rozhraní umožňující kdykoliv vyměnit nebo kombinovat OCR modely:
1. **Cloud AI Vision (`GeminiReceiptScanner`)**:
   - Primární model: **Google Gemini 2.0 Flash**.
   - Vynikající přesnost čtení českých účtenek, automatická extrakce položek, množství, DPH a celkové sumy do validního JSON formátu.
2. **Lokální offline záloha (`MlKitReceiptScanner`)**:
   - `google_mlkit_text_recognition`.
   - Zpracování přímo v zařízení bez nutnosti internetu a bez nákladů na API.
   - Slouží jako automatický fallback, pokud není zadán API klíč nebo je zařízení offline.
3. **Správce limitů (`TierAwareReceiptScanner`)**:
   - Řídí kvótu bezplatných AI skenů pro neplatící uživatele a neomezené skenování pro předplatitele.
4. **Ochrana soukromí a úspora nákladů**:
   - Fotografie účtenek jsou zpracovány **pouze dočasně v paměti / mezipaměti**.
   - Neukládají se trvale na server ani do cloudu, což šetří náklady na cloudové úložiště a chrání soukromí.

---

## ✏️ 4. Ruční zadávání výdajů (bez účtenky)

Pro výdaje, kde papírová účtenka neexistuje (např. společné taxi, nákup lístků, platba za benzín):
- **Rychlý souhrnný výdaj (Lumpsum)**:
  - Název (např. *"Taxi z letiště"*).
  - Částka (např. *300 Kč*).
  - Kdo platil.
  - Výběr členů pro rozdělení (výchozí: všichni rovným dílem, nebo volitelné zaškrtnutí).
- **Záznam přímého vyrovnání**:
  - Možnost zaznamenat hotovostní předání peněz nebo bankovní převod mezi dvěma konkrétními členy.

---

## 👥 5. Virtuální (dummy) členové a převzetí profilu (Account Takeover)

Řeší situaci, kdy v partě někdo **nemá aplikaci nainstalovanou**:

1. **Vytvoření virtuálního člena**:
   - Kdokoliv ve skupině může přidat kamaráda pouze zadáním jména (např. *"Honza"*).
   - V databázi je uložen s příznakem `is_virtual = true` a `user_id = null`.
   - Honzovi lze ihned přiřazovat útraty a počítat jeho dluhy.
2. **Převzetí profilu (Claim Profile)**:
   - Když si Honza později aplikaci stáhne a otevře odkaz pozvánky (`/invite/:code`), aplikace detekuje volné virtuální profily ve skupině.
   - Nabídne dialog: *"Existuje v této skupině profil 'Honza'. Jste to vy?"*.
   - Po potvrzení se profil propojí s jeho účtem (`user_id = auth.uid()`, `is_virtual = false`).
   - Veškerá historie a dluhy jsou plynule převedeny na jeho zařízení.

---

## 💳 6. Vyrovnání dluhů a bezpečnost bankovních údajů

### Zjednodušení dluhů (Debt Simplification)
- Implementován chamtivý (greedy) algoritmus minimálního toku hotovosti (`DebtSimplifier`).
- Převádí složitou síť vzájemných dluhů na **minimální možný počet transakcí** (např. místo 5 plateb mezi sebou proběhnou jen 2).

### Standard QR Platba (SPAYD)
- Generování standardního českého bankovního řetězce:
  `SPD*1.0*ACC:CZ6508000000192000145399*AM:200.00*CC:CZK*MSG:Split bill*`
- Plně kompatibilní se všemi českými bankami (Česká spořitelna, ČSOB, Air Bank, KB, Komerční banka, Raiffeisenbank, Fio, mBank atd.).
- Podpora pro evropský formát SEPA EPC QR.

### Bezpečnost IBANu (Zero-Knowledge přístup)
- **IBAN je uložen pouze lokálně v šifrovaném úložišti zařízení** (Android Keystore / iOS Keychain).
- **IBAN se neposílá ani neukládá na centrální server / Supabase databázi**, což eliminuje riziko úniku citlivých finančních údajů.
- QR kód se generuje dynamicky přímo na displeji telefonu věřitele v momentě platby.

---

## 🔗 7. Přihlašování, onboarding a deep linky

- **Okamžitý Guest režim**: Uživatel může ihned začít používat aplikaci bez zdlouhavé registrace (pouze zadá své zobrazované jméno).
- **Dodatečné propojení**: Možnost kdykoliv propojit účet s e-mailem nebo sociálním přihlášením pro synchronizaci na více zařízení.
- **Deep linky pozvánek**:
  - Formát App Links / Universal Links: `https://splitbill.app/invite/{code}`
  - Formát Custom Scheme: `splitbill://invite/{code}`
  - Automaticky přesměruje uživatele přímo do příslušné skupiny nebo k převzetí profilu.

---

## 💎 8. Monetizace a Freemium model

Integrace přes **RevenueCat** (`purchases_flutter`):
- **Model předplatného**: Měsíční a roční automaticky obnovované předplatné.
- **Bezplatná verze (Free)**:
  - Maximálně 2 aktivní skupiny.
  - Měsíční limit na přesné AI skenování přes Gemini (např. 5 skenů měsíčně, poté automatický přechod na lokální ML Kit).
- **Placená verze (Premium)**:
  - Neomezený počet skupin.
  - Neomezené AI skenování účtenek přes Gemini 2.0 Flash.
  - Export historie a vyrovnání do CSV.

---

## 💾 9. Datový model a architektura úložiště

### Lokální úložiště (Offline-first)
- Pro okamžitý provoz bez nutnosti počátečního nastavování cloudu aplikace využívá lokální mezipaměť (strukturovaný JSON / `shared_preferences`).

### Supabase Backend (připravené schéma)
Navrženo pro budoucí live synchronizaci:
- `users`: ID, email, jméno, čas vytvoření.
- `groups`: ID, název, unikátní kód pozvánky, vlastník.
- `group_members`: ID, ID skupiny, ID uživatele (nullable), zobrazované jméno, `is_virtual`.
- `expenses`: ID, ID skupiny, ID platícího člena, celková částka, název, čas.
- `expense_splits`: ID, ID výdaje, ID člena, dlužná částka.
- `settlements`: ID, ID skupiny, dlužník, věřitel, částka, čas vyrovnání.
- **Realtime synchronizace**: Živá aktualizace dat mezi telefony sedícími u jednoho stolu v reálném čase.

---

## 🎨 10. Vizuální identita a design

- **Styl**: Moderní, svěží a čistý design (kombinace tmavě modro-fialových akcentů `#1E1B4B`, smaragdově zelené pro příjem peněz `#10B981` a jemné korálové červené pro dluh `#EF4444`).
- **Tón textů**: Jasná, přirozená a věcná čeština bez nuceného slangu.
- **Přehlednost**: Kartový layout s velkými přehlednými čísly a zaoblenými ovládacími prvky.

---

## 🧪 11. Aktuální stav implementace a testy

- ✅ Hotový projektový skeleton a závislosti (`pubspec.yaml`).
- ✅ Nastavena oprávnění pro Android (`AndroidManifest.xml`) i iOS (`Info.plist`).
- ✅ Plně funkční a otestovaný algoritmus zjednodušení dluhů (`DebtSimplifier`).
- ✅ Implementovaný a otestovaný generátor české QR Platby (`QrPaymentService`).
- ✅ Funkční `GeminiReceiptScanner` (Gemini 2.0 Flash) s automatickým přechodem na `MlKitReceiptScanner`.
- ✅ Obrazovka skenování s podporou nativní kamery i demo účtenky.
- ✅ Obrazovka přiřazování položek s rozpočítáváním dýška a podporou virtuálních členů.
- ✅ 100% čistá statická analýza (`flutter analyze`: 0 chyb, 0 varování).
- ✅ 5 úspěšných jednotkových testů (`flutter test`).
- ✅ Veškerý kód verzován na GitHubu: **[https://github.com/Chlomek/split_bill](https://github.com/Chlomek/split_bill)**.
