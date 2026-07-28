// ============================================================
// link_utils.dart
// ПОЛНАЯ ВЕРСИЯ С ПОДДЕРЖКОЙ ВСЕХ ДОМЕНОВ
// ВКЛЮЧАЯ НОВЫЕ НИШИ: ЕДА, ФИТНЕС, ДЕТИ, ЗООТОВАРЫ, УКРАШЕНИЯ, ТЕХНИКА
// ============================================================

class LinkUtils {
  // 🔥 ОСНОВНЫЕ ДОМЕНЫ (ПОЛНЫЙ СПИСОК)
  static const List<String> coreDomains = [
    // ===== МУЗЫКА =====
    'spotify.com',
    'soundcloud.com',
    'apple.com',
    'tidal.com',
    'deezer.com',
    'bandcamp.com',

    // ===== ВИДЕО =====
    'youtube.com',
    'youtu.be',
    'vimeo.com',
    'twitch.tv',
    'bilibili.com',

    // ===== СОЦСЕТИ =====
    'instagram.com',
    'tiktok.com',
    'x.com',
    'twitter.com',
    'pinterest.com',
    'reddit.com',
    'telegram.org',
    't.me',
    'vk.com',
    'facebook.com',
    'linkedin.com',
    'discord.com',
    'whatsapp.com',
    'signal.org',
    'wechat.com',
    'line.me',
    'snapchat.com',

    // ===== МАГАЗИНЫ (ГЛОБАЛЬНЫЕ) =====
    'amazon.com',
    'ebay.com',
    'aliexpress.com',
    'etsy.com',
    'shopify.com',
    'myshopify.com',
    'farfetch.com',
    'walmart.com',
    'target.com',
    'wayfair.com',

    // ===== МАГАЗИНЫ (СНГ) =====
    'ozon.ru',
    'ozon.by',
    'wildberries.ru',
    'wildberries.by',
    '21vek.by',
    'lamoda.ru',
    'kaspi.kz',
    'detmir.ru',              // Детские товары
    'labirint.ru',            // Детские книги
    'mvideo.ru',              // Техника
    'eldorado.ru',            // Техника
    'citilink.ru',            // Техника
    'dns-shop.ru',            // Техника

    // ===== МАГАЗИНЫ (АЗИЯ) =====
    'shopee.com',
    'shopee.sg',
    'shopee.my',
    'shopee.ph',
    'shopee.id',
    'shopee.co.th',
    'shopee.vn',
    'lazada.com',
    'lazada.sg',
    'lazada.my',
    'lazada.ph',
    'lazada.id',
    'lazada.co.th',
    'lazada.vn',
    'tokopedia.com',
    'coupang.com',
    'flipkart.com',
    'rakuten.co.jp',

    // ===== МАГАЗИНЫ (ЕВРОПА) =====
    'zalando.com',
    'zalando.de',
    'zalando.fr',
    'zalando.it',
    'zalando.es',
    'zalando.nl',
    'asos.com',
    'shein.com',

    // ===== БРЕНДЫ (ОДЕЖДА) =====
    // Спортивные
    'nike.com',
    'adidas.com',
    'puma.com',
    'asics.com',
    'reebok.com',
    'underarmour.com',
    'decathlon.com',
    'sportsdirect.com',
    'newbalance.com',
    'saucony.com',
    'brooksrunning.com',
    'hoka.com',
    'salomon.com',

    // Горные / активный отдых
    'thenorthface.com',
    'patagonia.com',
    'columbia.com',
    'arcteryx.com',
    'mammut.com',
    'montbell.com',
    'millet.com',
    'eider.com',

    // Масс-маркет
    'zara.com',
    'hm.com',
    'uniqlo.com',
    'pullandbear.com',
    'bershka.com',
    'stradivarius.com',
    'mango.com',
    'guess.com',
    'superdry.com',
    'hollister.com',
    'abercrombie.com',
    'gap.com',
    'oldnavy.com',
    'ae.com',

    // Премиум
    'tommy.com',
    'calvinklein.com',
    'lacoste.com',
    'ralphlauren.com',

    // Джинсовая одежда
    'levi.com',  // 👈 ДОБАВЛЕНО

    // Обувь
    'converse.com',
    'vans.com',
    'timberland.com',
    'drmartens.com',
    'skechers.com',
    'crocs.com',

    // ===== ДОМ И ДЕКОР =====
    'ikea.com',
    'westelm.com',
    'crateandbarrel.com',
    'potterybarn.com',
    'anthropologie.com',
    'urbanoutfitters.com',
    'zarahome.com',
    'leroymerlin.ru',          // Стройматериалы
    'obi.ru',                  // Стройматериалы
    'petrovich.ru',            // Стройматериалы
    'vseinstrumenti.ru',       // Инструменты
    '220-volt.ru',             // Инструменты
    'tvoi-dom.ru',             // Стройматериалы

    // ===== КОСМЕТИКА =====
    'sephora.com',
    'ulta.com',
    'nyxcosmetics.com',
    'maccosmetics.com',
    'loccitane.com',
    'thebodyshop.com',
    'kiehls.com',
    'glossier.com',
    'fentybeauty.com',

    // ===== УКРАШЕНИЯ =====
    'pandora.net',
    'swarovski.com',
    'tiffany.com',
    'cartier.com',
    'sunlight.net',
    '585zolotoy.ru',
    'yashma.ru',

    // ===== СТРИМИНГ =====
    'netflix.com',
    'primevideo.com',
    'disneyplus.com',
    'hbomax.com',
    'max.com',
    'hulu.com',
    'mubi.com',
    'kinopoisk.ru',
    'ivi.ru',
    'okko.tv',

    // ===== IT / ДИЗАЙН =====
    'github.com',
    'figma.com',
    'behance.net',
    'dribbble.com',
    'artstation.com',
    'gitlab.com',
    'codepen.io',
    'stackoverflow.com',

    // ===== ИГРЫ =====
    'steampowered.com',
    'store.steampowered.com',
    'epicgames.com',
    'gog.com',
    'itch.io',
    'playstation.com',
    'xbox.com',
    'nintendo.com',
    'battle.net',

    // ===== КНИГИ / ОБРАЗОВАНИЕ =====
    'books.google.com',
    'play.google.com',
    'litres.ru',
    'audible.com',
    'coursera.org',
    'edx.org',
    'udemy.com',
    'skillshare.com',
    'khanacademy.org',
    'wikipedia.org',

    // ===== ФОТО =====
    'unsplash.com',
    'pexels.com',
    'shutterstock.com',

    // ===== ДРУГОЕ =====
    'notion.so',
    'miro.com',
    'canva.com',
    'medium.com',
    'substack.com',

    // ===== ПОИСКОВИКИ И КАРТЫ =====
    'yandex.com',
    'yandex.ru',
    'yandex.by',
    'yandex.kz',
    '2gis.ru',
    '2gis.kz',
    'mapbox.com',
    'openstreetmap.org',

    // ===== ОБЛАЧНЫЕ СЕРВИСЫ =====
    'drive.google.com',
    'dropbox.com',
    'onedrive.live.com',
    'icloud.com',
    'mega.nz',
    'box.com',
    'pcloud.com',

    // ===== ФИНАНСЫ =====
    'paypal.com',
    'stripe.com',
    'wise.com',
    'revolut.com',
    'venmo.com',
    'sberbank.ru',
    'tinkoff.ru',
    'alfabank.ru',
    'halykbank.kz',
    'qiwi.com',
    'raiffeisen.ru',
    'vtb.ru',
    'gazprombank.ru',
    'open.ru',
    'tochka.com',
    'modulbank.ru',
    'promsvyazbank.ru',
    'absolutbank.ru',
    'uniastrum.ru',

    // ===== БРОНИРОВАНИЕ И ПУТЕШЕСТВИЯ =====
    'booking.com',
    'agoda.com',
    'airbnb.com',
    'tripadvisor.com',
    'skyscanner.net',
    'kiwi.com',
    'expedia.com',
    'kayak.com',
    'hostelworld.com',
    'couchsurfing.com',
    'aviasales.ru',
    'tutu.ru',
    'rzd.ru',
    'blablacar.ru',

    // ===== ЗДОРОВЬЕ И АПТЕКИ =====
    'webmd.com',
    'mayoclinic.org',
    'nhs.uk',
    'apteka.ru',
    'zdravcity.ru',
    'iherb.com',
    'docdoc.ru',
    'onlinemedicine.ru',
    'medicalnewstoday.com',

    // ===== ФИТНЕС =====
    'fitstars.ru',
    'bodylab.ru',
    'fsport.ru',
    'biotechusa.com',
    'myprotein.com',
    'gymbeam.com',
    'fitbit.com',
    'garmin.com',
    'polar.com',
    'suunto.com',

    // ===== ДЕТСКИЕ ТОВАРЫ =====
    'pocemu4ek.ru',
    'korablik.ru',
    'mothercare.com',
    'hamleys.com',
    'mirkubikov.ru',

    // ===== ЗООТОВАРЫ =====
    'zoomagazin.ru',
    'betkhoven.ru',
    '4lapy.ru',
    'chewy.com',
    'petco.com',
    'petsmart.com',

    // ===== ЕДА И РЕЦЕПТЫ =====
    'lavka.yandex.ru',
    'sbermarket.ru',
    'fresh.ozon.ru',
    'vkusvill.ru',
    'dodopizza.ru',
    'sushiwok.ru',
    'tanuki.ru',
    'yakitoriya.ru',
    '1000.menu',
    'patee.ru',
    'eda.ru',
    'gastronom.ru',

    // ===== ТВОРЧЕСТВО =====
    'leonardo.ru',
    'peredvizhnik.ru',
    'artfox.ru',

    // ===== НОВОСТИ =====
    'weather.com',
    'accuweather.com',
    'bbc.com',
    'bbc.co.uk',
    'cnn.com',
    'nytimes.com',
    'wsj.com',
    'washingtonpost.com',
    'theguardian.com',
    'reuters.com',
    'apnews.com',
    'aljazeera.com',
    'dw.com',
    'france24.com',
    'euronews.com',
    'rt.com',
    'tass.ru',
    'ria.ru',
    'lenta.ru',
    'gazeta.ru',
    'kommersant.ru',
    'vedomosti.ru',
    'forbes.com',
    'forbes.ru',
    'bloomberg.com',
    'ft.com',
    'economist.com',
    'theatlantic.com',
    'newyorker.com',
    'time.com',
    'newsweek.com',
    'nationalgeographic.com',
    'sciencemag.org',
    'pnas.org',
    'nature.com',
    'sciencedaily.com',
    'livescience.com',
    'phys.org',
    'popularmechanics.com',
    'wired.com',
    'techcrunch.com',
    'theverge.com',
    'engadget.com',
    'arstechnica.com',
    'cnet.com',
    'zdnet.com',
    'gizmodo.com',
    'mashable.com',
    'buzzfeed.com',
    'huffpost.com',
    'vox.com',
    'politico.com',
    'axios.com',
    'businessinsider.com',
    'fastcompany.com',
    'inc.com',
    'entrepreneur.com',
    'hbr.org',
    'mit.edu',
    'stanford.edu',
    'harvard.edu',
    'ox.ac.uk',
    'cambridge.org',

    // ===== АВИАКОМПАНИИ =====
    'aeroflot.ru',
    's7.ru',
    's7-airlines.com',
    'utair.ru',
    'emirates.com',
    'turkishairlines.com',
    'lufthansa.com',
    'britishairways.com',
    'airfrance.com',
    'klm.com',
    'qatarairways.com',
    'singaporeair.com',
    'united.com',
    'delta.com',
    'americanairlines.com',
    'ryanair.com',
    'easyjet.com',
    'wizzair.com',
    'flydubai.com',
    'etihad.com',
    'jetblue.com',
    'southwest.com',
    'alaskaair.com',
    'aircanada.com',
    'ana.co.jp',
    'jal.co.jp',

    // ===== ДОСТАВКА ЕДЫ =====
    'delivery-club.ru',
    'foodora.com',
    'foodora.ru',
    'glovoapp.com',
    'ubereats.com',
    'doordash.com',
    'deliveroo.co.uk',
    'deliveroo.com',
    'just-eat.com',
    'just-eat.co.uk',
    'grubhub.com',
    'postmates.com',
    'wolt.com',
    'bolt.eu',
    'foodpanda.com',
    'talabat.com',
    'zomato.com',
    'swiggy.com',

    // ===== ТАКСИ И КАРШЕРИНГ =====
    'uber.com',
    'bolt.eu',
    'getaround.com',
    'sharenow.com',
    'car2go.com',
    'citymobil.ru',
    'gett.com',
    'lyft.com',

    // ===== РАБОТА И УСЛУГИ =====
    'hh.ru',
    'avito.ru',
    'cian.ru',
    'domclick.ru',
    'profi.ru',
    'youla.ru',
    'kwork.ru',
    'fl.ru',
    'rabota.ru',
    'superjob.ru',
    'zarplata.ru',
    'upwork.com',
    'freelancer.com',
    'fiverr.com',
    'toptal.com',

    // ===== ОНЛАЙН-ОБРАЗОВАНИЕ =====
    'skillbox.ru',
    'geekbrains.ru',
    'netology.ru',
    'stepik.org',
    'codecademy.com',
    'pluralsight.com',
    'lynda.com',
    'udacity.com',

    // ===== АВТО =====
    'avtocod.ru',
    'drom.ru',
    'auto.ru',
    'avtorun.ru',
    'drive2.ru',
    'avtopro.ru',             // Автотовары
    'exist.ru',               // Автозапчасти
    'emex.ru',                // Автозапчасти

    // ===== НЕДВИЖИМОСТЬ =====
    'domofond.ru',
    'm2.ru',

    // ===== КИНО И БИЛЕТЫ =====
    'afisha.ru',
    'ticketland.ru',
    'bilet.ru',
    'karabas.com',
    'kinoteatr.ru',

    // ===== СПОРТ И ФИТНЕС =====
    'fitnessfirst.ru',
    'worldclass.ru',
    'xfit.ru',

    // ===== ПОЧТА =====
    'gmail.com',
    'mail.ru',
    'outlook.com',
    'protonmail.com',

    // ===== ВИДЕОКОНФЕРЕНЦИИ =====
    'zoom.us',
    'webex.com',
    'teams.microsoft.com',

    // ===== ФАЙЛООБМЕННИКИ =====
    'mediafire.com',
    '4shared.com',
    'depositfiles.com',
    'turbobit.net',

    // ===== ХОСТИНГ И ПЛАТФОРМЫ =====
    'heroku.com',
    'netlify.com',
    'vercel.com',
    'aws.amazon.com',
    'azure.com',
    'wordpress.com',
    'blogger.com',
    'tumblr.com',
    'livejournal.com',

    // ===== ЗНАКОМСТВА =====
    'tinder.com',
    'bumble.com',
  ];

  // ========== ДИНАМИЧЕСКАЯ ПРОВЕРКА ==========
  static bool isAllowedDomain(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host;
      final lowerHost = host.toLowerCase();

      if (coreDomains.any((domain) =>
          lowerHost == domain ||
          lowerHost.endsWith('.$domain') ||
          domain.contains(lowerHost))) {
        return true;
      }

      const patterns = [
        'amazon.',
        'apple.com',
        'google.',
        'microsoft.com',
        'live.com',
        'yahoo.',
        'naver.com',
        'mercadolibre.',
        'gumtree.',
        'kijiji.',
        'takealot.com',
        'snapdeal.com',
        'bukalapak.com',
        'blibli.com',
        'tiki.vn',
        'sendo.vn',
        'taobao.com',
        'tmall.com',
        'jd.com',
        'pinduoduo.com',
        'meituan.com',
        'dianping.com',
        'baidu.com',
        'farfetch.',
        'yandex.',
        '2gis.',
        'booking.',
        'airbnb.',
        'tripadvisor.',
        'aviasales.',
        'tutu.',
        'sberbank.',
        'tinkoff.',
        'paypal.',
        'stripe.',
        'dropbox.',
        'onedrive.',
        'mega.nz',
        'whatsapp.',
        'signal.',
        'zoom.us',
        'bbc.',
        'cnn.',
        'nytimes.',
        'wsj.',
        'forbes.',
        'bloomberg.',
        'ft.com',
        'economist.',
        'nature.',
        'sciencemag.',
        'nationalgeographic.',
        'wired.',
        'theverge.',
        'techcrunch.',
        'arstechnica.',
        'cnet.',
        'gizmodo.',
        'mashable.',
        'buzzfeed.',
        'huffpost.',
        'vox.',
        'politico.',
        'axios.',
        'businessinsider.',
        'fastcompany.',
        'inc.com',
        'entrepreneur.',
        'hbr.org',
        'mit.edu',
        'stanford.edu',
        'harvard.edu',
        'ox.ac.uk',
        'cambridge.org',
        'aeroflot.',
        's7.ru',
        'utair.',
        'emirates.',
        'turkishairlines.',
        'lufthansa.',
        'britishairways.',
        'airfrance.',
        'klm.',
        'qatarairways.',
        'singaporeair.',
        'united.com',
        'delta.com',
        'americanairlines.',
        'ryanair.',
        'easyjet.',
        'wizzair.',
        'flydubai.',
        'etihad.',
        'jetblue.',
        'southwest.',
        'alaskaair.',
        'aircanada.',
        'ana.co.jp',
        'jal.co.jp',
        'delivery-club.',
        'foodora.',
        'glovoapp.',
        'ubereats.',
        'doordash.',
        'deliveroo.',
        'just-eat.',
        'grubhub.',
        'postmates.',
        'wolt.com',
        'bolt.eu',
        'foodpanda.',
        'talabat.',
        'zomato.',
        'swiggy.',
        'uber.com',
        'lyft.com',
        'gett.com',
        'getaround.',
        'sharenow.',
        'car2go.',
        'citymobil.',
        'raiffeisen.',
        'vtb.ru',
        'gazprombank.',
        'open.ru',
        'tochka.com',
        'modulbank.',
        'promsvyazbank.',
        'absolutbank.',
        'uniastrum.',
        'hh.ru',
        'avito.ru',
        'cian.ru',
        'domclick.',
        'profi.ru',
        'youla.ru',
        'kwork.ru',
        'fl.ru',
        'rabota.ru',
        'superjob.',
        'zarplata.',
        'upwork.com',
        'freelancer.',
        'fiverr.com',
        'toptal.',
        'skillbox.',
        'geekbrains.',
        'netology.',
        'stepik.',
        'codecademy.',
        'pluralsight.',
        'lynda.com',
        'udacity.',
        'avtocod.',
        'drom.ru',
        'auto.ru',
        'avtorun.',
        'drive2.',
        'domofond.',
        'm2.ru',
        'afisha.',
        'ticketland.',
        'bilet.ru',
        'karabas.',
        'kinoteatr.',
        'fitnessfirst.',
        'worldclass.',
        'xfit.',
        'docdoc.',
        'onlinemedicine.',
        'medicalnewstoday.',
        'eda.yandex.',
        'food.yandex.',
        'taxi.yandex.',
        'drive.yandex.',
        'lavka.yandex.',
        'fresh.ozon.',
        'sbermarket.',
        'vkusvill.',
        'dodopizza.',
        'sushiwok.',
        'tanuki.',
        'yakitoriya.',
        'leonardo.',
        'peredvizhnik.',
        'artfox.',
        'zoomagazin.',
        'betkhoven.',
        '4lapy.',
        'petco.',
        'petsmart.',
        'chewy.',
        'detmir.',
        'pocemu4ek.',
        'korablik.',
        'mothercare.',
        'hamleys.',
        'mirkubikov.',
        'fitstars.',
        'bodylab.',
        'fsport.',
        'biotechusa.',
        'myprotein.',
        'gymbeam.',
        'fitbit.',
        'garmin.',
        'polar.',
        'suunto.',
        'pandora.net',
        'swarovski.',
        'tiffany.',
        'cartier.',
        'sunlight.net',
        'yashma.ru',
        '585zolotoy.ru',
        'leroymerlin.',
        'obi.ru',
        'petrovich.',
        'vseinstrumenti.',
        '220-volt.ru',
        'tvoi-dom.ru',
        'avtopro.',
        'exist.ru',
        'emex.ru',
        'citilink.',
        'dns-shop.',
        'mvideo.',
        'eldorado.',
      ];

      for (final pattern in patterns) {
        if (lowerHost.contains(pattern)) return true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  // ========== ОПРЕДЕЛЕНИЕ ПЛАТФОРМЫ ==========
  static String detectPlatform(String url) {
    final lower = url.toLowerCase();

    // ---- МУЗЫКА ----
    if (lower.contains('spotify.com')) return 'spotify';
    if (lower.contains('soundcloud.com')) return 'soundcloud';
    if (lower.contains('apple.com/music') || lower.contains('music.apple.com')) return 'apple_music';
    if (lower.contains('tidal.com')) return 'tidal';
    if (lower.contains('deezer.com')) return 'deezer';
    if (lower.contains('bandcamp.com')) return 'bandcamp';

    // ---- ВИДЕО ----
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) return 'youtube';
    if (lower.contains('vimeo.com')) return 'vimeo';
    if (lower.contains('twitch.tv')) return 'twitch';
    if (lower.contains('bilibili.com')) return 'bilibili';

    // ---- СОЦСЕТИ ----
    if (lower.contains('instagram.com')) return 'instagram';
    if (lower.contains('tiktok.com')) return 'tiktok';
    if (lower.contains('x.com') || lower.contains('twitter.com')) return 'x';
    if (lower.contains('pinterest.com')) return 'pinterest';
    if (lower.contains('reddit.com')) return 'reddit';
    if (lower.contains('telegram.org') || lower.contains('t.me')) return 'telegram';
    if (lower.contains('vk.com')) return 'vk';
    if (lower.contains('facebook.com')) return 'facebook';
    if (lower.contains('linkedin.com')) return 'linkedin';
    if (lower.contains('snapchat.com')) return 'snapchat';
    if (lower.contains('discord.com')) return 'discord';
    if (lower.contains('whatsapp.com')) return 'whatsapp';
    if (lower.contains('signal.org')) return 'signal';
    if (lower.contains('wechat.com')) return 'wechat';
    if (lower.contains('line.me')) return 'line';

    // ---- МАГАЗИНЫ ----
    if (lower.contains('amazon.com') || lower.contains('amazon.')) return 'amazon';
    if (lower.contains('ozon.ru') || lower.contains('ozon.by')) return 'ozon';
    if (lower.contains('wildberries')) return 'wildberries';
    if (lower.contains('aliexpress.com')) return 'aliexpress';
    if (lower.contains('ebay.com')) return 'ebay';
    if (lower.contains('etsy.com')) return 'etsy';
    if (lower.contains('shopify.com') || lower.contains('myshopify.com')) return 'shopify';
    if (lower.contains('21vek.by')) return '21vek';
    if (lower.contains('lamoda.ru')) return 'lamoda';
    if (lower.contains('kaspi.kz')) return 'kaspi';
    if (lower.contains('flipkart.com')) return 'flipkart';
    if (lower.contains('shopee.')) return 'shopee';
    if (lower.contains('lazada.')) return 'lazada';
    if (lower.contains('tokopedia.com')) return 'tokopedia';
    if (lower.contains('coupang.com')) return 'coupang';
    if (lower.contains('rakuten.co.jp')) return 'rakuten';
    if (lower.contains('zalando.')) return 'zalando';
    if (lower.contains('asos.com')) return 'asos';
    if (lower.contains('shein.com')) return 'shein';
    if (lower.contains('farfetch.com') || lower.contains('farfetch.')) return 'farfetch';
    if (lower.contains('walmart.com')) return 'walmart';
    if (lower.contains('target.com')) return 'target';
    if (lower.contains('wayfair.com')) return 'wayfair';
    if (lower.contains('detmir.ru')) return 'detmir';
    if (lower.contains('labirint.ru')) return 'labirint';
    if (lower.contains('mvideo.ru')) return 'mvideo';
    if (lower.contains('eldorado.ru')) return 'eldorado';
    if (lower.contains('citilink.ru')) return 'citilink';
    if (lower.contains('dns-shop.ru')) return 'dns';

    // ---- БРЕНДЫ (ОДЕЖДА) ----
    if (lower.contains('nike.com')) return 'nike';
    if (lower.contains('adidas.com')) return 'adidas';
    if (lower.contains('puma.com')) return 'puma';
    if (lower.contains('asics.com')) return 'asics';
    if (lower.contains('reebok.com')) return 'reebok';
    if (lower.contains('underarmour.com')) return 'underarmour';
    if (lower.contains('decathlon.com')) return 'decathlon';
    if (lower.contains('sportsdirect.com')) return 'sportsdirect';
    if (lower.contains('newbalance.com')) return 'newbalance';
    if (lower.contains('saucony.com')) return 'saucony';
    if (lower.contains('brooksrunning.com')) return 'brooks';
    if (lower.contains('hoka.com')) return 'hoka';
    if (lower.contains('salomon.com')) return 'salomon';
    if (lower.contains('thenorthface.com')) return 'northface';
    if (lower.contains('patagonia.com')) return 'patagonia';
    if (lower.contains('columbia.com')) return 'columbia';
    if (lower.contains('arcteryx.com')) return 'arcteryx';
    if (lower.contains('mammut.com')) return 'mammut';
    if (lower.contains('montbell.com')) return 'montbell';
    if (lower.contains('millet.com')) return 'millet';
    if (lower.contains('eider.com')) return 'eider';
    if (lower.contains('zara.com')) return 'zara';
    if (lower.contains('hm.com')) return 'hm';
    if (lower.contains('uniqlo.com')) return 'uniqlo';
    if (lower.contains('pullandbear.com')) return 'pullandbear';
    if (lower.contains('bershka.com')) return 'bershka';
    if (lower.contains('stradivarius.com')) return 'stradivarius';
    if (lower.contains('mango.com')) return 'mango';
    if (lower.contains('guess.com')) return 'guess';
    if (lower.contains('superdry.com')) return 'superdry';
    if (lower.contains('hollister.com')) return 'hollister';
    if (lower.contains('abercrombie.com')) return 'abercrombie';
    if (lower.contains('gap.com')) return 'gap';
    if (lower.contains('oldnavy.com')) return 'oldnavy';
    if (lower.contains('ae.com')) return 'americaneagle';
    if (lower.contains('tommy.com')) return 'tommy';
    if (lower.contains('calvinklein.com')) return 'calvinklein';
    if (lower.contains('lacoste.com')) return 'lacoste';
    if (lower.contains('ralphlauren.com')) return 'ralphlauren';
    if (lower.contains('levi.com')) return 'levi';  // 👈 ДОБАВЛЕНО
    if (lower.contains('converse.com')) return 'converse';
    if (lower.contains('vans.com')) return 'vans';
    if (lower.contains('timberland.com')) return 'timberland';
    if (lower.contains('drmartens.com')) return 'drmartens';
    if (lower.contains('skechers.com')) return 'skechers';
    if (lower.contains('crocs.com')) return 'crocs';

    // ---- ДОМ И ДЕКОР ----
    if (lower.contains('ikea.com')) return 'ikea';
    if (lower.contains('westelm.com')) return 'westelm';
    if (lower.contains('crateandbarrel.com')) return 'crateandbarrel';
    if (lower.contains('potterybarn.com')) return 'potterybarn';
    if (lower.contains('anthropologie.com')) return 'anthropologie';
    if (lower.contains('urbanoutfitters.com')) return 'urbanoutfitters';
    if (lower.contains('zarahome.com')) return 'zarahome';
    if (lower.contains('leroymerlin.ru')) return 'leroymerlin';
    if (lower.contains('obi.ru')) return 'obi';
    if (lower.contains('petrovich.ru')) return 'petrovich';
    if (lower.contains('vseinstrumenti.ru')) return 'vseinstrumenti';
    if (lower.contains('220-volt.ru')) return 'volt220';
    if (lower.contains('tvoi-dom.ru')) return 'tvoidom';

    // ---- КОСМЕТИКА ----
    if (lower.contains('sephora.com')) return 'sephora';
    if (lower.contains('ulta.com')) return 'ulta';
    if (lower.contains('nyxcosmetics.com')) return 'nyx';
    if (lower.contains('maccosmetics.com')) return 'mac';
    if (lower.contains('loccitane.com')) return 'loccitane';
    if (lower.contains('thebodyshop.com')) return 'bodyshop';
    if (lower.contains('kiehls.com')) return 'kiehls';
    if (lower.contains('glossier.com')) return 'glossier';
    if (lower.contains('fentybeauty.com')) return 'fentybeauty';

    // ---- УКРАШЕНИЯ ----
    if (lower.contains('pandora.net')) return 'pandora';
    if (lower.contains('swarovski.com')) return 'swarovski';
    if (lower.contains('tiffany.com')) return 'tiffany';
    if (lower.contains('cartier.com')) return 'cartier';
    if (lower.contains('sunlight.net')) return 'sunlight';
    if (lower.contains('585zolotoy.ru')) return 'zolotoy585';
    if (lower.contains('yashma.ru')) return 'yashma';

    // ---- ЕДА ----
    if (lower.contains('lavka.yandex.ru')) return 'yandex_lavka';
    if (lower.contains('sbermarket.ru')) return 'sbermarket';
    if (lower.contains('fresh.ozon.ru')) return 'ozon_fresh';
    if (lower.contains('vkusvill.ru')) return 'vkusvill';
    if (lower.contains('dodopizza.ru')) return 'dodopizza';
    if (lower.contains('sushiwok.ru')) return 'sushiwok';
    if (lower.contains('tanuki.ru')) return 'tanuki';
    if (lower.contains('yakitoriya.ru')) return 'yakitoriya';
    if (lower.contains('1000.menu')) return 'menu1000';
    if (lower.contains('patee.ru')) return 'patee';
    if (lower.contains('eda.ru')) return 'eda';
    if (lower.contains('gastronom.ru')) return 'gastronom';

    // ---- ФИТНЕС ----
    if (lower.contains('fitstars.ru')) return 'fitstars';
    if (lower.contains('bodylab.ru')) return 'bodylab';
    if (lower.contains('fsport.ru')) return 'fsport';
    if (lower.contains('biotechusa.com')) return 'biotechusa';
    if (lower.contains('myprotein.com')) return 'myprotein';
    if (lower.contains('gymbeam.com')) return 'gymbeam';
    if (lower.contains('fitbit.com')) return 'fitbit';
    if (lower.contains('garmin.com')) return 'garmin';
    if (lower.contains('polar.com')) return 'polar';
    if (lower.contains('suunto.com')) return 'suunto';

    // ---- ДЕТСКИЕ ТОВАРЫ ----
    if (lower.contains('pocemu4ek.ru')) return 'pocemu4ek';
    if (lower.contains('korablik.ru')) return 'korablik';
    if (lower.contains('mothercare.com')) return 'mothercare';
    if (lower.contains('hamleys.com')) return 'hamleys';
    if (lower.contains('mirkubikov.ru')) return 'mirkubikov';

    // ---- ЗООТОВАРЫ ----
    if (lower.contains('zoomagazin.ru')) return 'zoomagazin';
    if (lower.contains('betkhoven.ru')) return 'betkhoven';
    if (lower.contains('4lapy.ru')) return 'lapy4';
    if (lower.contains('chewy.com')) return 'chewy';
    if (lower.contains('petco.com')) return 'petco';
    if (lower.contains('petsmart.com')) return 'petsmart';

    // ---- ТВОРЧЕСТВО ----
    if (lower.contains('leonardo.ru')) return 'leonardo';
    if (lower.contains('peredvizhnik.ru')) return 'peredvizhnik';
    if (lower.contains('artfox.ru')) return 'artfox';

    // ---- СТРИМИНГ ----
    if (lower.contains('netflix.com')) return 'netflix';
    if (lower.contains('primevideo.com')) return 'primevideo';
    if (lower.contains('disneyplus.com')) return 'disneyplus';
    if (lower.contains('hbomax.com') || lower.contains('max.com') || lower.contains('hbo.com')) return 'hbo';
    if (lower.contains('hulu.com')) return 'hulu';
    if (lower.contains('mubi.com')) return 'mubi';
    if (lower.contains('kinopoisk.ru')) return 'kinopoisk';
    if (lower.contains('ivi.ru')) return 'ivi';
    if (lower.contains('okko.tv')) return 'okko';

    // ---- IT / ДИЗАЙН ----
    if (lower.contains('github.com')) return 'github';
    if (lower.contains('figma.com')) return 'figma';
    if (lower.contains('behance.net')) return 'behance';
    if (lower.contains('dribbble.com')) return 'dribbble';
    if (lower.contains('artstation.com')) return 'artstation';
    if (lower.contains('gitlab.com')) return 'gitlab';
    if (lower.contains('codepen.io')) return 'codepen';
    if (lower.contains('stackoverflow.com')) return 'stackoverflow';

    // ---- ИГРЫ ----
    if (lower.contains('steampowered.com') || lower.contains('store.steampowered.com')) return 'steam';
    if (lower.contains('epicgames.com')) return 'epic';
    if (lower.contains('gog.com')) return 'gog';
    if (lower.contains('itch.io')) return 'itch';
    if (lower.contains('playstation.com')) return 'playstation';
    if (lower.contains('xbox.com')) return 'xbox';
    if (lower.contains('nintendo.com')) return 'nintendo';
    if (lower.contains('battle.net')) return 'battlenet';

    // ---- КНИГИ / ОБРАЗОВАНИЕ ----
    if (lower.contains('books.google.com') || lower.contains('play.google.com')) return 'google_books';
    if (lower.contains('litres.ru')) return 'litres';
    if (lower.contains('audible.com')) return 'audible';
    if (lower.contains('coursera.org')) return 'coursera';
    if (lower.contains('edx.org')) return 'edx';
    if (lower.contains('udemy.com')) return 'udemy';
    if (lower.contains('skillshare.com')) return 'skillshare';
    if (lower.contains('khanacademy.org')) return 'khanacademy';
    if (lower.contains('wikipedia.org')) return 'wikipedia';

    // ---- ФОТО ----
    if (lower.contains('unsplash.com')) return 'unsplash';
    if (lower.contains('pexels.com')) return 'pexels';
    if (lower.contains('shutterstock.com')) return 'shutterstock';

    // ---- ДРУГОЕ ----
    if (lower.contains('notion.so')) return 'notion';
    if (lower.contains('miro.com')) return 'miro';
    if (lower.contains('canva.com')) return 'canva';
    if (lower.contains('medium.com')) return 'medium';
    if (lower.contains('substack.com')) return 'substack';

    // ---- ПОИСК И КАРТЫ ----
    if (lower.contains('yandex.')) return 'yandex';
    if (lower.contains('2gis.')) return '2gis';
    if (lower.contains('mapbox.com')) return 'mapbox';
    if (lower.contains('openstreetmap.org')) return 'openstreetmap';

    // ---- ОБЛАЧНЫЕ СЕРВИСЫ ----
    if (lower.contains('drive.google.com')) return 'google_drive';
    if (lower.contains('dropbox.com')) return 'dropbox';
    if (lower.contains('onedrive.live.com')) return 'onedrive';
    if (lower.contains('icloud.com')) return 'icloud';
    if (lower.contains('mega.nz')) return 'mega';
    if (lower.contains('box.com')) return 'box';
    if (lower.contains('pcloud.com')) return 'pcloud';

    // ---- ФИНАНСЫ ----
    if (lower.contains('paypal.com')) return 'paypal';
    if (lower.contains('stripe.com')) return 'stripe';
    if (lower.contains('wise.com')) return 'wise';
    if (lower.contains('revolut.com')) return 'revolut';
    if (lower.contains('venmo.com')) return 'venmo';
    if (lower.contains('sberbank.ru')) return 'sberbank';
    if (lower.contains('tinkoff.ru')) return 'tinkoff';
    if (lower.contains('alfabank.ru')) return 'alfabank';
    if (lower.contains('halykbank.kz')) return 'halykbank';
    if (lower.contains('qiwi.com')) return 'qiwi';
    if (lower.contains('raiffeisen.ru')) return 'raiffeisen';
    if (lower.contains('vtb.ru')) return 'vtb';
    if (lower.contains('gazprombank.ru')) return 'gazprombank';
    if (lower.contains('open.ru')) return 'open';
    if (lower.contains('tochka.com')) return 'tochka';
    if (lower.contains('modulbank.ru')) return 'modulbank';
    if (lower.contains('promsvyazbank.ru')) return 'psb';
    if (lower.contains('absolutbank.ru')) return 'absolutbank';
    if (lower.contains('uniastrum.ru')) return 'uniastrum';

    // ---- БРОНИРОВАНИЕ И ПУТЕШЕСТВИЯ ----
    if (lower.contains('booking.com')) return 'booking';
    if (lower.contains('agoda.com')) return 'agoda';
    if (lower.contains('airbnb.com')) return 'airbnb';
    if (lower.contains('tripadvisor.com')) return 'tripadvisor';
    if (lower.contains('skyscanner.net')) return 'skyscanner';
    if (lower.contains('kiwi.com')) return 'kiwi';
    if (lower.contains('expedia.com')) return 'expedia';
    if (lower.contains('kayak.com')) return 'kayak';
    if (lower.contains('hostelworld.com')) return 'hostelworld';
    if (lower.contains('couchsurfing.com')) return 'couchsurfing';
    if (lower.contains('aviasales.ru')) return 'aviasales';
    if (lower.contains('tutu.ru')) return 'tutu';
    if (lower.contains('rzd.ru')) return 'rzd';
    if (lower.contains('blablacar.ru')) return 'blablacar';

    // ---- ЗДОРОВЬЕ ----
    if (lower.contains('webmd.com')) return 'webmd';
    if (lower.contains('mayoclinic.org')) return 'mayoclinic';
    if (lower.contains('nhs.uk')) return 'nhs';
    if (lower.contains('apteka.ru')) return 'apteka';
    if (lower.contains('zdravcity.ru')) return 'zdravcity';
    if (lower.contains('iherb.com')) return 'iherb';
    if (lower.contains('docdoc.ru')) return 'docdoc';
    if (lower.contains('onlinemedicine.ru')) return 'onlinemedicine';
    if (lower.contains('medicalnewstoday.com')) return 'medicalnewstoday';

    // ---- АВИАКОМПАНИИ ----
    if (lower.contains('aeroflot.ru')) return 'aeroflot';
    if (lower.contains('s7.ru') || lower.contains('s7-airlines.com')) return 's7';
    if (lower.contains('utair.ru')) return 'utair';
    if (lower.contains('emirates.com')) return 'emirates';
    if (lower.contains('turkishairlines.com')) return 'turkishairlines';
    if (lower.contains('lufthansa.com')) return 'lufthansa';
    if (lower.contains('britishairways.com')) return 'britishairways';
    if (lower.contains('airfrance.com')) return 'airfrance';
    if (lower.contains('klm.com')) return 'klm';
    if (lower.contains('qatarairways.com')) return 'qatarairways';
    if (lower.contains('singaporeair.com')) return 'singaporeair';
    if (lower.contains('united.com')) return 'united';
    if (lower.contains('delta.com')) return 'delta';
    if (lower.contains('americanairlines.com')) return 'americanairlines';
    if (lower.contains('ryanair.com')) return 'ryanair';
    if (lower.contains('easyjet.com')) return 'easyjet';
    if (lower.contains('wizzair.com')) return 'wizzair';
    if (lower.contains('flydubai.com')) return 'flydubai';
    if (lower.contains('etihad.com')) return 'etihad';
    if (lower.contains('jetblue.com')) return 'jetblue';
    if (lower.contains('southwest.com')) return 'southwest';
    if (lower.contains('alaskaair.com')) return 'alaskaair';
    if (lower.contains('aircanada.com')) return 'aircanada';
    if (lower.contains('ana.co.jp')) return 'ana';
    if (lower.contains('jal.co.jp')) return 'jal';

    // ---- ДОСТАВКА ЕДЫ ----
    if (lower.contains('delivery-club.ru')) return 'deliveryclub';
    if (lower.contains('foodora')) return 'foodora';
    if (lower.contains('glovoapp.com')) return 'glovo';
    if (lower.contains('ubereats.com')) return 'ubereats';
    if (lower.contains('doordash.com')) return 'doordash';
    if (lower.contains('deliveroo.co.uk') || lower.contains('deliveroo.com')) return 'deliveroo';
    if (lower.contains('just-eat')) return 'justeat';
    if (lower.contains('grubhub.com')) return 'grubhub';
    if (lower.contains('postmates.com')) return 'postmates';
    if (lower.contains('wolt.com')) return 'wolt';
    if (lower.contains('bolt.eu')) return 'bolt';
    if (lower.contains('foodpanda.com')) return 'foodpanda';
    if (lower.contains('talabat.com')) return 'talabat';
    if (lower.contains('zomato.com')) return 'zomato';
    if (lower.contains('swiggy.com')) return 'swiggy';

    // ---- ТАКСИ И КАРШЕРИНГ ----
    if (lower.contains('uber.com')) return 'uber';
    if (lower.contains('lyft.com')) return 'lyft';
    if (lower.contains('gett.com')) return 'gett';
    if (lower.contains('getaround.com')) return 'getaround';
    if (lower.contains('sharenow.com')) return 'sharenow';
    if (lower.contains('car2go.com')) return 'car2go';
    if (lower.contains('citymobil.ru')) return 'citymobil';

    // ---- РАБОТА И УСЛУГИ ----
    if (lower.contains('hh.ru')) return 'hh';
    if (lower.contains('avito.ru')) return 'avito';
    if (lower.contains('cian.ru')) return 'cian';
    if (lower.contains('domclick.ru')) return 'domclick';
    if (lower.contains('profi.ru')) return 'profi';
    if (lower.contains('youla.ru')) return 'youla';
    if (lower.contains('kwork.ru')) return 'kwork';
    if (lower.contains('fl.ru')) return 'fl';
    if (lower.contains('rabota.ru')) return 'rabota';
    if (lower.contains('superjob.ru')) return 'superjob';
    if (lower.contains('zarplata.ru')) return 'zarplata';
    if (lower.contains('upwork.com')) return 'upwork';
    if (lower.contains('freelancer.com')) return 'freelancer';
    if (lower.contains('fiverr.com')) return 'fiverr';
    if (lower.contains('toptal.com')) return 'toptal';

    // ---- АВТО ----
    if (lower.contains('avtocod.ru')) return 'avtocod';
    if (lower.contains('drom.ru')) return 'drom';
    if (lower.contains('auto.ru')) return 'auto';
    if (lower.contains('avtorun.ru')) return 'avtorun';
    if (lower.contains('drive2.ru')) return 'drive2';
    if (lower.contains('avtopro.ru')) return 'avtopro';
    if (lower.contains('exist.ru')) return 'exist';
    if (lower.contains('emex.ru')) return 'emex';

    // ---- ЯНДЕКС-СЕРВИСЫ ----
    if (lower.contains('eda.yandex.ru') || lower.contains('food.yandex.ru')) return 'yandex_eda';
    if (lower.contains('taxi.yandex.ru')) return 'yandex_taxi';
    if (lower.contains('drive.yandex.ru')) return 'yandex_drive';

    return 'link';
  }

  // ========== ПРОВЕРКА ВАЛИДНОСТИ URL ==========
  static bool isValidUrl(String value) {
    return Uri.tryParse(value)?.hasAbsolutePath ?? false;
  }

  // ========== ПОЛУЧЕНИЕ ОТОБРАЖАЕМОГО ИМЕНИ ==========
  static String getDisplayName(String url, {String? platform}) {
    final p = platform ?? detectPlatform(url);

    switch (p) {
      // ---- МУЗЫКА ----
      case 'spotify': return 'Spotify';
      case 'soundcloud': return 'SoundCloud';
      case 'apple_music': return 'Apple Music';
      case 'tidal': return 'Tidal';
      case 'deezer': return 'Deezer';
      case 'bandcamp': return 'Bandcamp';

      // ---- ВИДЕО ----
      case 'youtube': return 'YouTube';
      case 'vimeo': return 'Vimeo';
      case 'twitch': return 'Twitch';
      case 'bilibili': return 'Bilibili';

      // ---- СОЦСЕТИ ----
      case 'instagram': return 'Instagram';
      case 'tiktok': return 'TikTok';
      case 'x': return 'X';
      case 'pinterest': return 'Pinterest';
      case 'reddit': return 'Reddit';
      case 'telegram': return 'Telegram';
      case 'vk': return 'VK';
      case 'facebook': return 'Facebook';
      case 'linkedin': return 'LinkedIn';
      case 'snapchat': return 'Snapchat';
      case 'discord': return 'Discord';
      case 'whatsapp': return 'WhatsApp';
      case 'signal': return 'Signal';
      case 'wechat': return 'WeChat';
      case 'line': return 'LINE';

      // ---- МАГАЗИНЫ ----
      case 'amazon': return 'Amazon';
      case 'ozon': return 'Ozon';
      case 'wildberries': return 'Wildberries';
      case 'aliexpress': return 'AliExpress';
      case 'ebay': return 'eBay';
      case 'etsy': return 'Etsy';
      case 'shopify': return 'Shopify';
      case '21vek': return '21vek.by';
      case 'lamoda': return 'Lamoda';
      case 'kaspi': return 'Kaspi';
      case 'flipkart': return 'Flipkart';
      case 'shopee': return 'Shopee';
      case 'lazada': return 'Lazada';
      case 'tokopedia': return 'Tokopedia';
      case 'coupang': return 'Coupang';
      case 'rakuten': return 'Rakuten';
      case 'zalando': return 'Zalando';
      case 'asos': return 'ASOS';
      case 'shein': return 'SHEIN';
      case 'farfetch': return 'Farfetch';
      case 'walmart': return 'Walmart';
      case 'target': return 'Target';
      case 'wayfair': return 'Wayfair';
      case 'detmir': return 'Детский мир';
      case 'labirint': return 'Лабиринт';
      case 'mvideo': return 'М.Видео';
      case 'eldorado': return 'Эльдорадо';
      case 'citilink': return 'Ситилинк';
      case 'dns': return 'DNS';

      // ---- БРЕНДЫ (ОДЕЖДА) ----
      case 'nike': return 'Nike';
      case 'adidas': return 'Adidas';
      case 'puma': return 'Puma';
      case 'asics': return 'Asics';
      case 'reebok': return 'Reebok';
      case 'underarmour': return 'Under Armour';
      case 'decathlon': return 'Decathlon';
      case 'sportsdirect': return 'Sports Direct';
      case 'newbalance': return 'New Balance';
      case 'saucony': return 'Saucony';
      case 'brooks': return 'Brooks';
      case 'hoka': return 'Hoka';
      case 'salomon': return 'Salomon';
      case 'northface': return 'The North Face';
      case 'patagonia': return 'Patagonia';
      case 'columbia': return 'Columbia';
      case 'arcteryx': return 'Arc\'teryx';
      case 'mammut': return 'Mammut';
      case 'montbell': return 'Montbell';
      case 'millet': return 'Millet';
      case 'eider': return 'Eider';
      case 'zara': return 'Zara';
      case 'hm': return 'H&M';
      case 'uniqlo': return 'UNIQLO';
      case 'pullandbear': return 'Pull&Bear';
      case 'bershka': return 'Bershka';
      case 'stradivarius': return 'Stradivarius';
      case 'mango': return 'Mango';
      case 'guess': return 'Guess';
      case 'superdry': return 'Superdry';
      case 'hollister': return 'Hollister';
      case 'abercrombie': return 'Abercrombie & Fitch';
      case 'gap': return 'GAP';
      case 'oldnavy': return 'Old Navy';
      case 'americaneagle': return 'American Eagle';
      case 'tommy': return 'Tommy Hilfiger';
      case 'calvinklein': return 'Calvin Klein';
      case 'lacoste': return 'Lacoste';
      case 'ralphlauren': return 'Ralph Lauren';
      case 'levi': return 'Levi\'s';  // 👈 ДОБАВЛЕНО
      case 'converse': return 'Converse';
      case 'vans': return 'Vans';
      case 'timberland': return 'Timberland';
      case 'drmartens': return 'Dr. Martens';
      case 'skechers': return 'Skechers';
      case 'crocs': return 'Crocs';

      // ---- ДОМ И ДЕКОР ----
      case 'ikea': return 'IKEA';
      case 'westelm': return 'West Elm';
      case 'crateandbarrel': return 'Crate & Barrel';
      case 'potterybarn': return 'Pottery Barn';
      case 'anthropologie': return 'Anthropologie';
      case 'urbanoutfitters': return 'Urban Outfitters';
      case 'zarahome': return 'Zara Home';
      case 'leroymerlin': return 'Леруа Мерлен';
      case 'obi': return 'OBI';
      case 'petrovich': return 'Петрович';
      case 'vseinstrumenti': return 'ВсеИнструменты';
      case 'volt220': return '220 Вольт';
      case 'tvoidom': return 'Твой Дом';

      // ---- КОСМЕТИКА ----
      case 'sephora': return 'Sephora';
      case 'ulta': return 'Ulta Beauty';
      case 'nyx': return 'NYX';
      case 'mac': return 'MAC';
      case 'loccitane': return 'L\'Occitane';
      case 'bodyshop': return 'The Body Shop';
      case 'kiehls': return 'Kiehl\'s';
      case 'glossier': return 'Glossier';
      case 'fentybeauty': return 'Fenty Beauty';

      // ---- УКРАШЕНИЯ ----
      case 'pandora': return 'Pandora';
      case 'swarovski': return 'Swarovski';
      case 'tiffany': return 'Tiffany & Co.';
      case 'cartier': return 'Cartier';
      case 'sunlight': return 'Sunlight';
      case 'zolotoy585': return '585 Золотой';
      case 'yashma': return 'Яшма Золото';

      // ---- ЕДА ----
      case 'yandex_lavka': return 'Яндекс Лавка';
      case 'sbermarket': return 'СберМаркет';
      case 'ozon_fresh': return 'Ozon Fresh';
      case 'vkusvill': return 'ВкусВилл';
      case 'dodopizza': return 'Додо Пицца';
      case 'sushiwok': return 'Суши Wok';
      case 'tanuki': return 'Тануки';
      case 'yakitoriya': return 'Якитория';
      case 'menu1000': return '1000 меню';
      case 'patee': return 'Patee';
      case 'eda': return 'Eda.ru';
      case 'gastronom': return 'Gastronom';

      // ---- ФИТНЕС ----
      case 'fitstars': return 'FitStars';
      case 'bodylab': return 'BodyLab';
      case 'fsport': return 'Формула Спорта';
      case 'biotechusa': return 'BiotechUSA';
      case 'myprotein': return 'MyProtein';
      case 'gymbeam': return 'GymBeam';
      case 'fitbit': return 'Fitbit';
      case 'garmin': return 'Garmin';
      case 'polar': return 'Polar';
      case 'suunto': return 'Suunto';

      // ---- ДЕТСКИЕ ТОВАРЫ ----
      case 'pocemu4ek': return 'Почемучек';
      case 'korablik': return 'Кораблик';
      case 'mothercare': return 'Mothercare';
      case 'hamleys': return 'Hamleys';
      case 'mirkubikov': return 'Мир кубиков';

      // ---- ЗООТОВАРЫ ----
      case 'zoomagazin': return 'Зоомагазин';
      case 'betkhoven': return 'Бетховен';
      case 'lapy4': return 'Четыре Лапы';
      case 'chewy': return 'Chewy';
      case 'petco': return 'Petco';
      case 'petsmart': return 'Petsmart';

      // ---- ТВОРЧЕСТВО ----
      case 'leonardo': return 'Леонардо';
      case 'peredvizhnik': return 'Передвижник';
      case 'artfox': return 'ArtFox';

      // ---- СТРИМИНГ ----
      case 'netflix': return 'Netflix';
      case 'primevideo': return 'Prime Video';
      case 'disneyplus': return 'Disney+';
      case 'hbo': return 'HBO Max';
      case 'hulu': return 'Hulu';
      case 'mubi': return 'Mubi';
      case 'kinopoisk': return 'Кинопоиск';
      case 'ivi': return 'IVI';
      case 'okko': return 'Okko';

      // ---- IT / ДИЗАЙН ----
      case 'github': return 'GitHub';
      case 'figma': return 'Figma';
      case 'behance': return 'Behance';
      case 'dribbble': return 'Dribbble';
      case 'artstation': return 'ArtStation';
      case 'gitlab': return 'GitLab';
      case 'codepen': return 'CodePen';
      case 'stackoverflow': return 'Stack Overflow';

      // ---- ИГРЫ ----
      case 'steam': return 'Steam';
      case 'epic': return 'Epic Games';
      case 'gog': return 'GOG';
      case 'itch': return 'itch.io';
      case 'playstation': return 'PlayStation';
      case 'xbox': return 'Xbox';
      case 'nintendo': return 'Nintendo';
      case 'battlenet': return 'Battle.net';

      // ---- КНИГИ / ОБРАЗОВАНИЕ ----
      case 'google_books': return 'Google Books';
      case 'litres': return 'Литрес';
      case 'audible': return 'Audible';
      case 'coursera': return 'Coursera';
      case 'edx': return 'edX';
      case 'udemy': return 'Udemy';
      case 'skillshare': return 'Skillshare';
      case 'khanacademy': return 'Khan Academy';
      case 'wikipedia': return 'Wikipedia';

      // ---- ФОТО ----
      case 'unsplash': return 'Unsplash';
      case 'pexels': return 'Pexels';
      case 'shutterstock': return 'Shutterstock';

      // ---- ДРУГОЕ ----
      case 'notion': return 'Notion';
      case 'miro': return 'Miro';
      case 'canva': return 'Canva';
      case 'medium': return 'Medium';
      case 'substack': return 'Substack';

      // ---- ПОИСК И КАРТЫ ----
      case 'yandex': return 'Яндекс';
      case '2gis': return '2ГИС';
      case 'mapbox': return 'Mapbox';
      case 'openstreetmap': return 'OpenStreetMap';

      // ---- ОБЛАЧНЫЕ СЕРВИСЫ ----
      case 'google_drive': return 'Google Drive';
      case 'dropbox': return 'Dropbox';
      case 'onedrive': return 'OneDrive';
      case 'icloud': return 'iCloud';
      case 'mega': return 'Mega';
      case 'box': return 'Box';
      case 'pcloud': return 'pCloud';

      // ---- ФИНАНСЫ ----
      case 'paypal': return 'PayPal';
      case 'stripe': return 'Stripe';
      case 'wise': return 'Wise';
      case 'revolut': return 'Revolut';
      case 'venmo': return 'Venmo';
      case 'sberbank': return 'Сбербанк';
      case 'tinkoff': return 'Тинькофф';
      case 'alfabank': return 'Альфа-Банк';
      case 'halykbank': return 'Halyk Bank';
      case 'qiwi': return 'QIWI';
      case 'raiffeisen': return 'Райффайзенбанк';
      case 'vtb': return 'ВТБ';
      case 'gazprombank': return 'Газпромбанк';
      case 'open': return 'Открытие';
      case 'tochka': return 'Точка';
      case 'modulbank': return 'Модульбанк';
      case 'psb': return 'Промсвязьбанк';
      case 'absolutbank': return 'Абсолют Банк';
      case 'uniastrum': return 'Юниаструм Банк';

      // ---- БРОНИРОВАНИЕ И ПУТЕШЕСТВИЯ ----
      case 'booking': return 'Booking.com';
      case 'agoda': return 'Agoda';
      case 'airbnb': return 'Airbnb';
      case 'tripadvisor': return 'Tripadvisor';
      case 'skyscanner': return 'Skyscanner';
      case 'kiwi': return 'Kiwi.com';
      case 'expedia': return 'Expedia';
      case 'kayak': return 'Kayak';
      case 'hostelworld': return 'Hostelworld';
      case 'couchsurfing': return 'Couchsurfing';
      case 'aviasales': return 'Aviasales';
      case 'tutu': return 'Туту.ру';
      case 'rzd': return 'РЖД';
      case 'blablacar': return 'BlaBlaCar';

      // ---- ЗДОРОВЬЕ ----
      case 'webmd': return 'WebMD';
      case 'mayoclinic': return 'Mayo Clinic';
      case 'nhs': return 'NHS';
      case 'apteka': return 'Аптека.ру';
      case 'zdravcity': return 'ЗдравСити';
      case 'iherb': return 'iHerb';
      case 'docdoc': return 'DocDoc';
      case 'onlinemedicine': return 'OnlineMedicine';
      case 'medicalnewstoday': return 'Medical News Today';

      // ---- АВИАКОМПАНИИ ----
      case 'aeroflot': return 'Аэрофлот';
      case 's7': return 'S7 Airlines';
      case 'utair': return 'UTair';
      case 'emirates': return 'Emirates';
      case 'turkishairlines': return 'Turkish Airlines';
      case 'lufthansa': return 'Lufthansa';
      case 'britishairways': return 'British Airways';
      case 'airfrance': return 'Air France';
      case 'klm': return 'KLM';
      case 'qatarairways': return 'Qatar Airways';
      case 'singaporeair': return 'Singapore Airlines';
      case 'united': return 'United Airlines';
      case 'delta': return 'Delta Air Lines';
      case 'americanairlines': return 'American Airlines';
      case 'ryanair': return 'Ryanair';
      case 'easyjet': return 'easyJet';
      case 'wizzair': return 'Wizz Air';
      case 'flydubai': return 'Flydubai';
      case 'etihad': return 'Etihad Airways';
      case 'jetblue': return 'JetBlue';
      case 'southwest': return 'Southwest Airlines';
      case 'alaskaair': return 'Alaska Airlines';
      case 'aircanada': return 'Air Canada';
      case 'ana': return 'ANA';
      case 'jal': return 'Japan Airlines';

      // ---- ДОСТАВКА ЕДЫ ----
      case 'deliveryclub': return 'Delivery Club';
      case 'foodora': return 'Foodora';
      case 'glovo': return 'Glovo';
      case 'ubereats': return 'Uber Eats';
      case 'doordash': return 'DoorDash';
      case 'deliveroo': return 'Deliveroo';
      case 'justeat': return 'Just Eat';
      case 'grubhub': return 'Grubhub';
      case 'postmates': return 'Postmates';
      case 'wolt': return 'Wolt';
      case 'bolt': return 'Bolt';
      case 'foodpanda': return 'Foodpanda';
      case 'talabat': return 'Talabat';
      case 'zomato': return 'Zomato';
      case 'swiggy': return 'Swiggy';

      // ---- ТАКСИ И КАРШЕРИНГ ----
      case 'uber': return 'Uber';
      case 'lyft': return 'Lyft';
      case 'gett': return 'Gett';
      case 'getaround': return 'Getaround';
      case 'sharenow': return 'Share Now';
      case 'car2go': return 'Car2Go';
      case 'citymobil': return 'Ситимобил';

      // ---- РАБОТА И УСЛУГИ ----
      case 'hh': return 'HeadHunter';
      case 'avito': return 'Avito';
      case 'cian': return 'Циан';
      case 'domclick': return 'ДомКлик';
      case 'profi': return 'Профи';
      case 'youla': return 'Юла';
      case 'kwork': return 'Kwork';
      case 'fl': return 'FL.ru';
      case 'rabota': return 'Работа.ру';
      case 'superjob': return 'SuperJob';
      case 'zarplata': return 'Зарплата.ру';
      case 'upwork': return 'Upwork';
      case 'freelancer': return 'Freelancer';
      case 'fiverr': return 'Fiverr';
      case 'toptal': return 'Toptal';

      // ---- ОНЛАЙН-ОБРАЗОВАНИЕ ----
      case 'skillbox': return 'Skillbox';
      case 'geekbrains': return 'GeekBrains';
      case 'netology': return 'Нетология';
      case 'stepik': return 'Stepik';
      case 'codecademy': return 'Codecademy';
      case 'pluralsight': return 'Pluralsight';
      case 'lynda': return 'LinkedIn Learning';
      case 'udacity': return 'Udacity';

      // ---- АВТО ----
      case 'avtocod': return 'Автокод';
      case 'drom': return 'Drom.ru';
      case 'auto': return 'Auto.ru';
      case 'avtorun': return 'Авторун';
      case 'drive2': return 'Drive2.ru';
      case 'avtopro': return 'AvtoPro';
      case 'exist': return 'Exist';
      case 'emex': return 'Emex';

      // ---- ЯНДЕКС-СЕРВИСЫ ----
      case 'yandex_eda': return 'Яндекс Еда';
      case 'yandex_taxi': return 'Яндекс Такси';
      case 'yandex_drive': return 'Яндекс Драйв';

      default:
        try {
          return Uri.parse(url).host.replaceAll('www.', '');
        } catch (_) {
          return 'Link';
        }
    }
  }
}