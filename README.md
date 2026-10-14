# ALIREZATUNEL

پنل کاریز با گزینهٔ موتور **BackPack** در همان بخش ساخت و مدیریت تانل.
نام نمایشی پنل **ALIREZATUNEL** است؛ طراحی، استایل‌ها و ساختار اصلی پنل کاریز حفظ شده‌اند.
کل سورس کاریز، سورس موتور BackPack، رابط وب، نصب‌کننده، تست‌ها و راهنمای فارسی در این بسته هستند.

## آپلود روی گیت‌هاب

این بسته برای مخزن زیر آماده شده است:

https://github.com/alirezachatgpt97-coder/ALIREZA-TUUNEL

ZIP جدید بدون پوشهٔ اضافی بسته‌بندی شده است. پس از استخراج، `bootstrap.sh`،
`install.sh`، `Cargo.toml` و `README.md` کنار هم قرار دارند.

دو روش برای آپلود دارید:

1. **روش ساده:** فقط فایل `bootstrap.sh` استخراج‌شده و خود فایل
   `ALIREZATUNEL-GITHUB.zip` را کنار هم در ریشهٔ مخزن روی شاخهٔ `main` آپلود کنید.
   نیازی به آپلود تک‌تک فایل‌های پروژه نیست؛ اسکریپت ZIP را خودکار استخراج می‌کند.
2. **سورس کامل:** محتویات استخراج‌شدهٔ همین ZIP را با Git یا GitHub Desktop
   در ریشهٔ همان مخزن آپلود کنید. `Cargo.toml` و `bootstrap.sh` باید در صفحهٔ اصلی
   مخزن دیده شوند؛ پوشهٔ اضافی `ALIREZATUNEL` دور فایل‌ها قرار نگیرد.

اگر روش اول را انتخاب می‌کنید، فقط یک ZIP از پروژه در ریشهٔ مخزن نگه دارید تا
نصب‌کننده بین نسخه‌های مختلف ZIP سردرگم نشود.

## نصب تک‌خطی پنل

پس از آپلود، روی سرور **Ubuntu یا Debian با systemd و دسترسی root** اجرا کنید:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/alirezachatgpt97-coder/ALIREZA-TUUNEL/main/bootstrap.sh) panel
```

اسکریپت بستهٔ پروژه، ابزارهای ساخت و Rust/Cargo، Node.js 22 و نسخهٔ Go موردنیاز
موتور را دریافت می‌کند، برنامه‌ها را می‌سازد و سرویس پنل را نصب می‌کند.
در پایان IP عمومی یا دامنه را می‌پرسد و لینک یک‌بارمصرف ورود را نشان می‌دهد.
برای سرور بدون curl، ابتدا `apt-get update && apt-get install -y curl ca-certificates` را اجرا کنید.

نسخه با IP یا دامنهٔ مشخص:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/alirezachatgpt97-coder/ALIREZA-TUUNEL/main/bootstrap.sh) panel --host YOUR_PUBLIC_IP
```

### نصب سرور دوم / agent

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/alirezachatgpt97-coder/ALIREZA-TUUNEL/main/bootstrap.sh) agent
```

در پنل، گزینهٔ اضافه‌کردن سرور را انتخاب کنید و کد اتصال را به اسکریپت بدهید.
اگر بعداً می‌خواهید سرور را وصل کنید:

```bash
sudo alirezatunel-join JOIN_CODE_FROM_PANEL
```

بعد از اتصال دو سرور، در فرم ساخت تانل گزینهٔ **backpack** را انتخاب کنید.
پورت‌های پنل، ارتباط agent، تانل و سرویس‌ها باید در فایروال مجاز باشند.
ساخت اول به اینترنت و فضای کافی نیاز دارد و ممکن است چند دقیقه طول بکشد.
این دستورها روی سرور لینوکس اجرا می‌شوند، نه در CMD ویندوز.
نصب خودکار کامل روی VPS هنوز آزمایش نشده است؛ وضعیت آزمون‌های پروژه در
[گزارش بررسی ساخت](docs/BUILD_VERIFICATION.md) آمده است.

### بررسی بسته بدون نصب

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/alirezachatgpt97-coder/ALIREZA-TUUNEL/main/bootstrap.sh) --check-source
```

### نصب دستی از سورس

اگر ابزارهای ساخت از قبل نصب هستند:

```bash
sudo bash install.sh panel
sudo kariz-panel login-link --host YOUR_SERVER_IP
```

[راهنمای کامل فارسی و تنظیمات پیشرفته](docs/ALIREZATUNEL.md)

## امکانات

- ۱۲ روش انتقال معکوس BackPack، شامل Stealth، PCK، KCP/FEC، QUIC و ICMP.
- مستقیم لایهٔ ۳ با carrierهای UDP، PCK، QUIC، SNI، ICMP و raw IP.
- پروفایل‌های سرعت، FEC، مسیرهای جایگزین، health failover و load balancing.
- ساخت، ویرایش، تعویض توکن و مدیریت دو سر تانل از همان پنل.
- وضعیت واقعی اتصال موتور، نمودار ترافیک، لاگ systemd و هشدارها.
- تونل ترافیک سرویس‌های پروکسی، WireGuard و DNS موجود با انتخاب صحیح TCP/UDP.

موتور BackPack جداگانه اجرا می‌شود و پروتکل کاریز تغییر نکرده است.
پنل، سرویس WireGuard، DNS یا کانفیگ پروکسی جدید ایجاد نمی‌کند؛ ترافیک آن‌ها را حمل می‌کند.
جزئیات امکانات ادغام‌شده و محدودیت‌های آزمون در راهنما آمده‌اند.

## ساخت و آزمون

```bash
bash scripts/build-alirezatunel.sh
ALIREZATUNEL_BACKPACK_BINARY="$PWD/build/alirezatunel-backpack" cargo test -p kariz-panel --lib --test backpack
```

ساخت اول وابستگی‌ها را از اینترنت دریافت می‌کند. نتیجه در `build/` قرار می‌گیرد.
برای نصب از ساخت آمادهٔ همین معماری: `sudo bash install.sh panel --no-build`.

## Attribution

Based on BackPack by Amin Mohammadi (AminMGMT)
https://github.com/AminMGMT/BackPack

Based on the supplied Kariz archive by Erfan-XRay.
Original notices and licenses remain in `LICENSE`, `NOTICE` and `engines/backpack/`.
The Kariz license restricts modified/rebranded deployment and distribution; this package does not grant additional rights.

Original upstream documentation is retained in `docs/UPSTREAM_README.md`,
`docs/UPSTREAM_README_FA.md`, `docs/` and `engines/backpack/docs/`.
