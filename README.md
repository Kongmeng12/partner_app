# PhaPhak Partner app

Flutter app ສຳລັບເຈົ້າຂອງທີ່ພັກ — ກິນ API `/api/partner/*` ຂອງ backend ໃນ `kong/backend`.

> **ໝາຍເຫດ**: ໂຟນເດີນີ້ຢູ່ **ນອກ** repo `kong/` ໂດຍຕັ້ງໃຈ — ຈຶ່ງບໍ່ຖືກ push ຂຶ້ນ
> repo `weblaostay` ພ້ອມກັບ backend/webadmin.
>
> ມັນມີ **git repo ຂອງຕົນເອງ** ຢູ່ `github.com/Kongmeng12/partner_app` —
> ມີ version control ແລະ backup ຄົບ, ພຽງແຕ່ແຍກກັນ.

## ຄັ້ງທຳອິດ

```bash
flutter doctor --android-licenses    # ຕ້ອງພິມ y ເອງ — ບໍ່ຮັບ = build APK ບໍ່ໄດ້
flutter pub get
```

## ແລ່ນ

ເປີດ API ກ່ອນ:

```bash
cd d:\kong\laostay\kong
npm run dev          # API :3100 + WebAdmin :5173 + ເວັບລູກຄ້າ :5174
```

ຈາກນັ້ນ:

```bash
cd d:\kong\laostay\partner_app
flutter emulators --launch Pixel_4_XL_API_33
flutter run
```

ເຂົ້າສູ່ລະບົບດ້ວຍບັນຊີຈາກ seed:

| ອີເມວ | ລະຫັດຜ່ານ | ສະຖານະ |
|---|---|---|
| `` | `Partner@2026` | verified |
| `homsabay@laostay.la` | `Partner@2026` | verified |


ที่พัก	Email	รหัสผ่าน
Vang Vieng Riverside	vangvieng@laostay.la	Partner@2026
Mekong View Resort	mekongview@laostay.la	Partner@2026
Dokchampa Homestay	newapplicant@laostay.la	Partner@2026


ສະໝັກໃໝ່ຜ່ານໜ້າ "ສະໝັກເປັນ Partner" ຈະໄດ້ບັນຊີ `pending` —
ອະນຸມັດຢູ່ WebAdmin ໜ້າ *ອະນຸມັດ Partner* ແລ້ວກົດ "ກວດສະຖານະອີກຄັ້ງ" ໃນແອັບ.

### API base URL

ເລືອກອັດຕະໂນມັດຕາມບ່ອນແລ່ນ ([lib/core/config.dart](lib/core/config.dart)):

| ບ່ອນແລ່ນ | URL |
|---|---|
| Android emulator | `http://10.0.2.2:3100/api` |
| Chrome / desktop | `http://localhost:3100/api` |

`10.0.2.2` ຄືວິທີທີ່ emulator ຕິດຕໍ່ຫາເຄື່ອງແມ່ — `localhost` ໃນ emulator ໝາຍເຖິງຕົວ emulator ເອງ.

ເຄື່ອງຈິງ ຫຼື server ຈິງ ໃຫ້ override:

```bash
flutter run --dart-define=API_BASE_URL=https://api.laostay.la/api
```

ແລ່ນເທິງ Chrome **ຕ້ອງລະບຸ port ຄົງທີ່** — `flutter run -d chrome` ເສີຍໆ ຈະສຸ່ມ port
ໃໝ່ທຸກຄັ້ງ ແລະ port ສຸ່ມ ໃສ່ allowlist ຂອງ CORS ບໍ່ໄດ້. `5175` ຖືກເພີ່ມໃສ່
`CORS_ORIGIN` ໃນ `kong/backend/.env` ໄວ້ແລ້ວ:

```bash
flutter run -d chrome --web-port 5175
```

ໃຊ້ port ອື່ນ → browser ບລັອກທຸກ request ແລ້ວແອັບຂຶ້ນ *"ໂຫຼດລາຍຊື່ແຂວງບໍ່ໄດ້"*
ຢູ່ໜ້າສະໝັກ. ຖ້າແກ້ `.env` ຕ້ອງ restart backend ນຳ — `nest --watch` ເບິ່ງແຕ່ `src/`
ບໍ່ໄດ້ເບິ່ງ `.env`.

## ທົດສອບ

```bash
flutter analyze            # ຕ້ອງບໍ່ມີ issue
flutter test               # 31 ຂໍ້ — ບໍ່ຕ້ອງມີ backend
flutter test --tags live --run-skipped   # 10 ຂໍ້ — ຍິງໃສ່ API ຈິງ (ຕ້ອງ npm run dev ຢູ່ກ່ອນ)
```

`--run-skipped` **ຈຳເປັນ** — `skip` ໃນ `dart_test.yaml` ຄືສິ່ງທີ່ກັນມັນອອກຈາກການແລ່ນປົກກະຕິ
ແລະ ການເລືອກ tag ຢ່າງດຽວບໍ່ລົບລ້າງ skip.

`--tags live` ([test/live_api_test.dart](test/live_api_test.dart)) ໃຊ້ `ApiClient` ແລະ model
ຂອງແອັບເອງຍິງໃສ່ backend ຈິງ — ຖ້າ server ປ່ຽນຊື່ field ມັນຈະລົ້ມຢູ່ນີ້ ບໍ່ແມ່ນກາຍເປັນ
ໜ້າຈໍເປົ່າຢູ່ມືຖືຂອງ partner. ກວດ: login · dashboard (`gross = commission + net`) ·
ຈຳນວນຄືນທີ່ client ກັບ server ຕ້ອງຄິດຕົງກັນ ·
`subtotal + fee + tax + cleaning − discount = total` · `payout = total − commission` ·
ປະຕິທິນຕ້ອງໄດ້ 1 ແຖວຕໍ່ຄືນ · **partner B ຕ້ອງໄດ້ 404 ຢູ່ການຈອງຂອງ partner A**.

ສິ່ງທີ່ test ຄຸ້ມກັນໄວ້ (ບໍ່ແມ່ນເພື່ອຕົວເລກ coverage ແຕ່ເພື່ອບັກທີ່ເຄີຍເກີດຈິງ):

- `dates_test.dart` — `date` column ມາເປັນ UTC midnight; ອ່ານດ້ວຍ local getter
  ຈະຄາດເຄື່ອນ 1 ວັນ. ນີ້ຄືບັກທີ່ backend README ໝາຍວ່າ "ເຄີຍພາດມາແລ້ວ"
- `api_client_test.dart` — 401 ຫຼາຍອັນພ້ອມກັນຕ້ອງ refresh **ຄັ້ງດຽວ**;
  backend ຖືວ່າ refresh token ທີ່ໃຊ້ຊ້ຳຄືຖືກລັກ ແລ້ວຕັດທຸກ session ຖິ້ມ
- `money_test.dart` — ຕົວເລກຕ້ອງກົງກັບ `webadmin/src/lib/format.ts`
- `auth_stage_test.dart` — partner `pending` ຕ້ອງໄປໜ້າ "ລໍອະນຸມັດ" ບໍ່ແມ່ນ dashboard

## ໂຄງສ້າງ

```
lib/
├─ core/         config · api_client (refresh ຄັ້ງດຽວ) · token_store · money · dates
├─ theme/        tokens.dart  ← ຈຸດດຽວທີ່ຕ້ອງແກ້ເມື່ອໄດ້ design ໃໝ່
├─ models/       id ເປັນ String ສະເໝີ · ເງິນເປັນ int ກີບ
├─ providers/    auth · data (Riverpod)
├─ screens/
└─ widgets/
```

**ໜ້າຕາ**: token ທັງໝົດດຶງມາຈາກ `webadmin/src/theme.ts` ເຊິ່ງ lift ມາຈາກ mockup ຈິງ.
ເມື່ອໄດ້ design ຂອງແອັບແລ້ວ ໃຫ້ແກ້ `lib/theme/tokens.dart` ໄຟລ໌ດຽວ.

## ຈຸດທີ່ຜິດງ່າຍ

- **id ເປັນ String** — ທຸກ id ໃນ DB ເປັນ `int8` ແລະ backend ສົ່ງເປັນ string
  (ຄ່າເກີນ 2^53 ຈະເພີ້ຍນຖ້າ parse ເປັນ number). ຢ່າແປງເປັນ `int`
- **ເງິນເປັນ `int` ກີບເຕັມ** — ບໍ່ມີເສດ, ຢ່າໃຊ້ `double` ຈັກບ່ອນ
- **ວັນທີ** — ໃຊ້ helper ໃນ `core/dates.dart` ສະເໝີ ຢ່າ `DateTime.parse(x).day` ເອງ
- **ສະຖານະການຈອງເປັນຂັ້ນບັນໄດທາງດຽວ** confirmed → staying → completed;
  ຍົກເລີກຕ້ອງຜ່ານ `/cancel` ເພາະມັນຄິດເງິນຄືນ
- **Walk-in** `serviceFee = 0` ແລະ ໃຊ້ອັດຕາຄອມ walk-in — ຄິດຢູ່ server ບໍ່ແມ່ນຢູ່ແອັບ
- **ຄັງຫ້ອງເປັນຕົວເລກ ບໍ່ແມ່ນ ຈອງ/ວ່າງ** — ຫ້ອງແບບໜຶ່ງມີຫຼາຍຫ້ອງ ຄືນທີ່ຂາຍໄປ 2 ຈາກ 8
  ຍັງຂາຍໄດ້ ແລະ ຍັງແກ້ລາຄາໄດ້. ປະຕິທິນຈຶ່ງເລືອກໄດ້ທຸກຄືນ ແລະ ສະແດງ `3/8`
- **ລາຄາ ກັບ ເປີດ/ປິດ ຢູ່ຄົນລະ endpoint** — `room_prices` ກັບ `room_inventory`
  ແຍກກັນ ເພື່ອໃຫ້ປິດຄືນໃດຄືນໜຶ່ງບໍ່ໄປແຕະລາຄາທີ່ມັນຈະເປີດຄືນvintage@laostay.la
#   p a r t n e r _ a p p 
 
 