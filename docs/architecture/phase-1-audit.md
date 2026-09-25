# ممیزی معماری فاز ۱: Mirza Bot → SaaS چندمستاجری

تاریخ: ۲۰۲۶-۰۹-۲۵. مبنا: مخزن عمومی `mahdiMGF2/mirzabot` در commit `6ee7c942296e455ae0d0fdae007dda9dc6904c3d`. این مخزن Fork اختصاصی شما نیست؛ تا زمانی که URL یا checkout آن ارائه نشود، تفاوت‌های Fork و داده‌های نصب فعلی ناشناخته‌اند. این گزارش تحلیل ایستای کد است؛ هیچ سرویس، پایگاه داده، توکن واقعی یا webhook آزمایش نشده است. کد مخزن تغییر نکرده است.

## ۱. نقشهٔ اجرا و وابستگی

`install.sh` تنظیمات و webhook اصلی را می‌سازد → `config.php` یک PDO و یک `$APIKEY`/دامنه/ادمین سراسری تعریف می‌کند → `index.php` به عنوان webhook اصلی `botapi.php`, `function.php`, `keyboard.php`, `panels.php` و `admin.php` را به کار می‌گیرد. `panels.php` آداپترهای Marzban, Marzneshin, Alireza/Sanaei, S-UI, Hiddify, WireGuard Dashboard, MikroTik و IBSng را بارگذاری می‌کند؛ Pasarguard در README ذکر شده ولی برای پوشش اجرایی آن باید مسیرهای پیاده‌سازی دقیق‌تر ردیابی شود. `payment/*.php` callbackهای پرداخت را به همان PDO و توابع سراسری متصل می‌کنند. `sub/index.php` مسیر اشتراک است. `app/` خروجی ساخت Mini App است و `api/verify.php` و `api/miniapp.php` احراز هویت و داده‌های آن را تأمین می‌کنند. `panel/` پنل وب سرور اصلی است.

`vpnbot/Default/` قالب ربات نماینده است. `api/users.php:usr_active_bot_agent` و مسیر مشابه در `admin.php` آن را برای هر ربات در `vpnbot/{chat_id}{username}` کپی، `config.php` آن را با توکن جایگزین، و webhook جدا تنظیم می‌کنند. `botsaz` توکن، شناسهٔ مالک و تنظیمات را نگه می‌دارد. این چندرباته‌بودن فعلی، یک هستهٔ اجرایی یکپارچه نیست؛ کد تکراری، مسیر فایل و وضعیت JSON برای هر bot دارد. ساخت ربات در میانهٔ عملیات فایل/webhook/INSERT تراکنش جبرانی ندارد و حذف آن پوشه و سطر را فوراً حذف می‌کند.

## ۲. داده و کلیدهای هویتی

`db/tables.php` تعداد ۲۹ جدول را فهرست می‌کند: `user`, `help`, `setting`, `admin`, `channels`, `marzban_panel`, `product`, `invoice`, `Payment_report`, `Discount`, `Giftcodeconsumed`, `PaySetting`, `DiscountSell`, `affiliates`, `shopSetting`, `cancel_service`, `service_other`, `card_number`, `Requestagent`, `topicid`, `manualsell`, `departman`, `support_message`, `wheel_list`, `botsaz`, `app`, `logs_api`, `category`, `reagent_report`. شناسهٔ `user.id` همان Telegram user ID و کلید اصلی سراسری است؛ یک کاربر تلگرام در دو ربات مستقل با این مدل دو رکورد مجزا ندارد. `invoice.id_invoice` نیز کلید اصلی سراسری است. `user.bottype` توکن ربات را در متن آشکار نگه می‌دارد. `botsaz.bot_token` و `marzban_panel.password_panel` نیز متن آشکارند. `botsaz.id_user` صاحب ربات نماینده است؛ این را نباید بی‌بررسی با مالک Tenant SaaS یکی گرفت. روابط غالباً شناسه/نام متنی و بدون FK هستند.

`db/bootstrap.php` تعریف جدول‌ها، migrationهای 001–012 و indexها را فراخوانی می‌کند. `db/Schema.php` خطای migration را ثبت و ادامه می‌دهد؛ ledger نسخهٔ اجراشده/rollback عمومی ندارد. `function.php` حین `update()` حتی می‌تواند ستون جدید ایجاد کند. این دو رفتار برای migration کنترل‌شدهٔ SaaS باید کنار گذاشته یا محدود شوند. indexهای فعلی در `db/indexes.php` عمدتاً تک‌ستونی هستند و هیچ index ترکیبی Tenant ندارند.

| دامنهٔ داده | جدول‌های فعلی | کلید پیشنهادی و نکتهٔ مهاجرت |
| --- | --- | --- |
| هویت SaaS | `admin` نقش مدیر ربات است؛ `user` مشتری تلگرام است | `tenants`, `accounts`, `tenant_memberships`, `roles/permissions`, `sessions` جدید؛ `owner_id` به account اشاره کند، نه Telegram ID |
| ربات | `botsaz`, `setting`, `topicid`, `channels`, `app` | `bots` جدید با `tenant_id`, UUID و token رمزنگاری‌شده؛ تنظیمات وابسته به tenant و در صورت ماهیت رباتی `bot_id` |
| مشتری و فروش | `user`, `invoice`, `Payment_report`, `service_other`, `manualsell`, `cancel_service`, `reagent_report` | `tenant_id` و در دادهٔ مربوط به ربات `bot_id`؛ کلید یکتای مشتری `(tenant_id, bot_id, telegram_user_id)`؛ ارجاع‌ها باید با کلیدهای همان scope اعتبارسنجی شوند |
| کاتالوگ/پنل | `marzban_panel`, `product`, `category`, `shopSetting`, `PaySetting`, `card_number`, `Discount`, `DiscountSell`, `Giftcodeconsumed` | `tenant_id` و هر جا تنظیمات یا محصول متعلق به یک bot است `bot_id`؛ تصمیم اشتراک‌گذاری بین botهای یک tenant باید پیش از schema نهایی گرفته شود |
| پشتیبانی/بازاریابی/گزارش | `affiliates`, `Requestagent`, `departman`, `support_message`, `help`, `wheel_list`, `logs_api` | `tenant_id` و بسته به منبع `bot_id`, `actor_account_id`؛ audit جدا از log درخواست لازم است |
| زیرساخت | فاقد مدل SaaS | `plans`, `subscriptions`, `tenant_domains`, `jobs`, `backup_manifests`, `audit_events`, `bot_health` با scope و index مناسب |

برای همهٔ ۲۹ جدول باید در فاز ۲ ماتریس ستونی/ارجاعی نهایی و نمونه‌دادهٔ نصب واقعی بررسی شود؛ موارد با دادهٔ JSON و فایل ممکن است مالکیت پنهان داشته باشند. `tenant_id` به تنهایی روی queryها کافی نیست: همهٔ UPDATE/DELETE/INSERT، joins، callbackها و side effectهای پنل VPN نیز باید در همان context بررسی شوند.

## ۳. احراز هویت، پنل و API

`panel/login.php` از session، CSRF، password_verify و ارتقای تدریجی گذرواژهٔ متن آشکار استفاده می‌کند؛ `panel/inc/config.php:require_auth` فقط `admin.rule=administrator` را می‌پذیرد. rate limit فایل موقت به ازای IP است و session expiry/RBAC/Tenant context ندارد. `panel/index.php` آمار همهٔ `user` و `invoice` را می‌خواند؛ `panel/user.php`, `panel/product.php` و مسیرهای دیگر lookup/تغییر بر اساس ID تنها دارند. این‌ها در وضعیت فعلی برای SaaS قابل عرضه نیستند.

API مدیریتی در `api/utils.php` یک توکن سراسری از `api/hash.txt` یا `$APIKEY` را می‌پذیرد؛ `apiRequestContext()` بدنهٔ درخواست را در `logs_api` ذخیره می‌کند و redaction فقط برای چند header انجام می‌شود. بدنهٔ شامل `token` در `api/users.php` ممکن است در log ذخیره شود. `api/verify.php` امضای Telegram initData را با توکن اصلی بررسی و توکن نشست را در `user.token` ذخیره می‌کند؛ `api/miniapp.php` bearer token را به `user` نگاشت می‌کند. هر دو برای multi-bot باید bot context معتبر داشته باشند. `payment/*.php` و `sub/index.php` نیز باید از شناسهٔ پرداخت/اشتراک، tenant را در سرور پیدا کنند و هرگز به tenant_id ورودی اعتماد نکنند.

## ۴. cron، بکاپ و امنیت فعلی

`cronbot/run.php` یک dispatcher دقیقه‌ای با flock و ۱۶ job زمان‌بندی‌شده در `cronbot/jobs.php` دارد؛ queue پایدار و retry/lease per tenant ندارد. `activeconfig.php`/`disableconfig.php` از `ORDER BY RAND() LIMIT 10` روی user استفاده می‌کنند؛ انتخاب تصادفی برای مقیاس بزرگ و تضمین پردازش مناسب نیست. `backupbot.php` از کل دیتابیس SQL dump می‌گیرد و به چت گزارشی تلگرام می‌فرستد؛ فایل‌های ربات‌های نماینده را جداگانه archive و ارسال می‌کند. restore امن، manifest نسخه‌دار، tenant-scoped export/import یا preview یافت نشد. dump شامل تنظیمات و credentialها خواهد بود.

خطرهای قطعی از کد: توکن در `config.php` تولیدی، `vpnbot/.../config.php`، `botsaz`, `user.bottype` و URL تماس‌های Telegram وجود دارد؛ secret webhook در query string است (`function.php:1692,1716,1727`). `api/utils.php:logApiRequest` بدنه را بدون حذف secrets ثبت می‌کند. `function.php:update` بعضی فیلدهای حساس را redacted می‌کند ولی فهرست آن کامل نیست. `checktelegramip` و secret webhook لایه‌هایی از دفاع‌اند، اما onboarding و routing چند tenant را حل نمی‌کنند. audit ایستا جای pentest یا بررسی deployment را نمی‌گیرد.

## ۵. انتخاب معماری سازگار با کد

| گزینه | مزیت | مانع | تصمیم |
| --- | --- | --- | --- |
| A: کپی کامل نصب برای هر tenant | تغییر کم در کد | مغایر یک application/DB و هزینهٔ نگهداری بالا | رد |
| B: یک DB و یک application با tenant/bot context صریح | حفظ آداپترها و منطق کسب‌وکار، رشد تدریجی | نیازمند بازبینی تمام queryها و کلیدها | انتخاب هدف |
| C: DB جدا برای هر tenant با PHP مشترک | جداسازی دادهٔ قوی‌تر | provisioning/migration/اتصال و گزارش سراسری پیچیده‌تر | گزینهٔ آینده برای tenantهای خاص |

در B، webhook مشترک `/telegram/webhook/{bot_uuid}` ابتدا bot را با UUID پیدا می‌کند و header مخفی `X-Telegram-Bot-Api-Secret-Token` را مستقل از UUID بررسی می‌کند؛ سپس `TenantContext` غیرقابل‌تغییر از bot فعال به handler تزریق می‌شود. endpointهای پنل Tenant context را فقط از session/account membership می‌گیرند. jobها tenant_id و bot_id را به‌صورت payload امضاشده/تأییدشده حمل می‌کنند و worker دوباره مالکیت و وضعیت اشتراک را می‌سنجد. repository/service layer برای queryهای tenant-scoped جای helperهای آزاد فعلی می‌نشیند؛ کدهای قدیمی تا مهاجرت کامل در مسیر tenant اولیه محصور می‌مانند.

تعیین مرز مشتری مهم است: آیا هر tenant می‌تواند چند bot با مشتری/محصول/پنل مشترک داشته باشد، یا این منابع برای هر bot مستقل‌اند؟ پیشنهاد: مالکیت ریشه با tenant؛ مشتری و تراکنش با bot_id، و محصول/پنل با tenant_id و اتصال اختیاری به bot. این انتخاب باید روی دادهٔ Fork واقعی راستی‌آزمایی شود.

## ۶. برنامهٔ مهاجرت بدون از دست‌دادن داده

۱. پیش از هر DDL، inventory schema واقعی، تعداد رکوردها، duplicateهای Telegram ID/شماره سفارش، فایل‌های `vpnbot/*/data` و credentialها؛ snapshot سازگار DB + فایل، آزمایش restore در محیط جدا.

۲. migration نسخه‌دار و قابل ازسرگیری: افزودن tenant اصلی، accounts/roles/bots و ستون‌های nullable `tenant_id`/`bot_id`، سپس backfill دسته‌ای و بررسی شمارش و orphanها. دادهٔ اصلی با legacy bot پیوند داده شود؛ botهای `botsaz` بعد از نقشه‌برداری از `bottype` و JSONها به bots جدید نگاشت شوند. یکتایی `(tenant_id, bot_id, telegram_user_id)` نیازمند تغییر PK قدیمی `user.id` به کلید داخلی است؛ قبل از آن dual-write و shadow reads/validation لازم است.

۳. فعال‌سازی تدریجی tenant-scoped repositories، API، webhook، پنل و callback؛ feature flag و آزمون A/B/C برای IDOR. پس از تطبیق رکوردها، FK/index/NOT NULL و حذف مسیر legacy. DDL MySQL عموماً rollback تراکنشی تضمین‌شده ندارد؛ recovery از snapshot و migration رو به جلو طراحی شود. هیچ rollout production بدون checkpoint و آزمایش بازیابی.

۴. توکن‌ها با AEAD و key خارج repository، fingerprint HMAC با کلید مستقل برای uniqueness، rotation version و masked UI نگهداری شوند. secretهای قدیمی در فایل/DB پس از cutover پاک‌سازی و توکن‌های لو رفته rotate شوند. backup رمزنگاری‌شده، نسخه‌دار، whitelist schema، streaming و atomic restore در staging برای یک tenant؛ هیچ SQL dump دلخواه برای restore اجرا نشود.

## ۷. ترتیب اجرا و معیار خروج

- فاز ۲: schema versioning، tenant/bot/account foundations، backfill و invariantهای دیتابیس؛ هنوز دسترسی مشتری SaaS باز نشود.
- فاز ۳: session امن، membership/RBAC، scoped repositories و تست‌های cross-tenant برای CRUD/API/side effects.
- فازهای ۴–۵: پنل Master و پنل Tenant بر پایهٔ همان policy؛ impersonation با audit و expiry.
- فاز ۶: Bot Manager مشترک، lifecycle و webhook header secret؛ مهاجرت botهای فایل‌محور با حفظ قابلیت‌های فعلی.
- فاز ۷: plan/limits/grace/suspension بدون حذف داده.
- فاز ۸: backup/restore tenant-aware با preview و isolation test.
- فاز ۹: queue DB/Redis با lease/idempotency/retry و scheduler دسته‌ای؛ monitoring worker.
- فازهای ۱۰–۱۲: secret hygiene، webhook/payment/SSRF/XSS/CSRF/IDOR audit، index و load profile در ۱۰/۵۰/۱۰۰/۵۰۰ tenant، آزمون عملی restore و recovery.

## گزارش پایان فاز ۱

Changed Files: هیچ. New Files: فقط همین گزارش خارج از Repository. Database Changes: هیچ. Security Changes: هیچ؛ ریسک‌ها مستند شدند. Performance Changes: هیچ. Tests: بررسی ایستای فایل‌ها، schema و مسیرهای اجرا؛ تست runtime/load اجرا نشده است. Remaining Work: دسترسی به Fork واقعی و snapshot schema بدون secrets، تعیین مرز اشتراک منابع بین botها، سپس فاز ۲ با migrationهای جداگانه و تست‌های جداسازی.
