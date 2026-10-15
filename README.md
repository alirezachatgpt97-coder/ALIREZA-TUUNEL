# ALIREZATUNEL — نصب بدون کامپایل

ظاهر، امکانات و پروتکل‌های پروژه حفظ شده‌اند. موتور BackPack همراه هسته و پنل کاریز در بستهٔ اجرایی قرار دارد. نصب‌کننده Rust، Go و Node نصب نمی‌کند؛ فقط فایل اجرایی متناسب با پردازنده را دانلود و پس از بررسی SHA256 نصب می‌کند. سرور Linux دارای systemd لازم است.

## آپلود در گیت‌هاب

این ZIP را روی کامپیوتر استخراج کنید. فایل‌های `bootstrap.sh`، `install.sh`، `SHA256SUMS` و دو فایل `ALIREZATUNEL-linux-*.tar.gz` را در ریشهٔ مخزن زیر آپلود کنید؛ خود فایل‌های tar.gz را استخراج نکنید:

https://github.com/alirezachatgpt97-coder/ALIREZA-TUUNEL

فایل `ALIREZATUNEL-SOURCE.zip` هم سورس کامل همین نسخه است؛ آن را بدون استخراج در همان مخزن نگه دارید. هر فایل جداگانه آپلود می‌شود و نیازی به آپلود هزاران فایل نیست.

## نصب پنل، با کاربر root

```bash
curl -fL --retry 3 https://raw.githubusercontent.com/alirezachatgpt97-coder/ALIREZA-TUUNEL/main/bootstrap.sh -o /root/alirezatunel-install.sh && bash /root/alirezatunel-install.sh panel
```

## نصب سرور عامل

```bash
curl -fL --retry 3 https://raw.githubusercontent.com/alirezachatgpt97-coder/ALIREZA-TUUNEL/main/bootstrap.sh -o /root/alirezatunel-install.sh && bash /root/alirezatunel-install.sh agent
```

سپس در پنل سرور را اضافه کنید و فرمان `alirezatunel-join` نمایش‌داده‌شده را روی عامل اجرا کنید.

## نصب دستی با یک اسکریپت

فایل `install.sh` همین بسته را در `/root` قرار دهید؛ این فایل بقیهٔ بسته را از مخزن دانلود می‌کند:

```bash
bash /root/install.sh panel
```

## نصب دستی از بستهٔ اجرایی

فایل tar.gz مناسب معماری سرور را به همراه SHA256SUMS در یک پوشه کپی کنید؛ سپس با root (برای ARM64 نام فایل را عوض کنید):

```bash
sha256sum -c SHA256SUMS --ignore-missing
tar -xzf ALIREZATUNEL-linux-amd64.tar.gz
bash install.sh panel --no-build
```

برای لینک ورود:

```bash
kariz-panel login-link --host SERVER_IP
```

این بسته زمان کامپایل روی VPS را حذف می‌کند. زمان دانلود به اتصال شبکه بستگی دارد؛ RAM یک‌گیگ تضمین ظرفیت همهٔ بارهای ترافیکی نیست. سرویس‌ها و داده‌های موجود در مسیرهای اصلی کاریز حفظ می‌شوند. مجوزها و انتساب‌های سورس داخل بسته موجود است.
