// lib/utils/link_utils.dart

// ============================================================
// link_utils.dart
// ПОЛНАЯ ВЕРСИЯ С ПОДДЕРЖКОЙ ВСЕХ ДОМЕНОВ
// ВКЛЮЧАЯ НОВЫЕ НИШИ: МОДА, КОСМЕТИКА, УКРАШЕНИЯ, ЖЕНСКИЕ СЕРВИСЫ
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
    'distrokid.com',
    'tunecore.com',
    'cdbaby.com',
    'amuse.io',
    'recordunion.com',
    'bandlab.com',
    'soundtrap.com',
    'landr.com',
    'mastering.com',
    'vocalremover.org',

    // ===== ВИДЕО =====
    'youtube.com',
    'youtu.be',
    'vimeo.com',
    'twitch.tv',
    'bilibili.com',
    'dailymotion.com',
    'likee.com',
    'kwai.com',
    'mojo.com',
    'kick.com',
    'rumble.com',
    'odysee.com',
    'facebookgaming.com',
    'clapper.tv',
    'triller.com',
    'firework.com',
    'clipchamp.com',
    'zoom.tv',
    'vigo-video.com',
    'snackvideo.com',

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
    'threads.net',
    'bluesky.social',
    'mastodon.social',
    'clubhouse.com',
    'parler.com',
    'gettr.com',
    'weibo.com',
    'weibo.cn',
    'renren.com',
    'qzone.qq.com',
    'ok.ru',
    'dzen.ru',
    'vc.ru',
    'habr.com',
    'pikabu.ru',
    'be.real',
    'irrelevant.com',
    'distro.media',
    'weverse.io',
    'vspc.com',
    'foto.com',
    'cyberpin.com',
    'spoutible.com',
    'verification.io',
    'gab.com',
    'meetme.com',
    'ask.fm',
    'spring.me',
    'curiouscat.me',
    'tellonym.me',
    'sarafan.ru',
    'livejournal.com',

    // ===== ПЛАТФОРМЫ ДЛЯ ТВОРЦОВ =====
    'patreon.com',
    'boosty.to',
    'donationalerts.com',
    'donatello.com',
    'buymeacoffee.com',
    'ko-fi.com',
    'tipjar.com',
    'gumroad.com',
    'sellfy.com',
    'payhip.com',
    'podia.com',
    'stan.store',
    'whop.com',

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
    'taobao.com',
    'tmall.com',
    'jd.com',
    'pinduoduo.com',
    'meituan.com',
    'dianping.com',
    'shein.com',
    'romwe.com',
    'cider.com',
    'myntra.com',
    'nykaa.com',
    'ajio.com',
    'snapdeal.com',
    'souq.com',
    'noon.com',
    'namshi.com',

    // ===== МАГАЗИНЫ (СНГ) =====
    'ozon.ru',
    'ozon.by',
    'wildberries.ru',
    'wildberries.by',
    '21vek.by',
    'lamoda.ru',
    'kaspi.kz',
    'detmir.ru',
    'labirint.ru',
    'mvideo.ru',
    'eldorado.ru',
    'citilink.ru',
    'dns-shop.ru',
    'megamarket.ru',
    'sbermarket.ru',
    'market.yandex.ru',
    'goods.ru',
    'perekrestok.ru',
    'utkonos.ru',
    'samokat.ru',
    'kurer.ru',
    'lenta.com',

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
    'blibli.com',
    'bukalapak.com',

    // ===== МАГАЗИНЫ (ЕВРОПА) =====
    'zalando.com',
    'zalando.de',
    'zalando.fr',
    'zalando.it',
    'zalando.es',
    'zalando.nl',
    'asos.com',

    // ===== ПЛАТФОРМЫ ДЛЯ МЕРЧА =====
    'redbubble.com',
    'society6.com',
    'teepublic.com',
    'zazzle.com',
    'printful.com',
    'printify.com',
    'merch.amazon.com',
    'gooten.com',
    'podrocks.com',
    'spreadshirt.com',

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
    'massimodutti.com',
    'oysho.com',
    'reiss.com',
    'karenmillen.com',
    'hobbs.com',
    'coastfashion.com',
    'whistles.com',
    'phase-eight.com',
    'lkbennett.com',
    'tedbaker.com',
    'kurtgeiger.com',
    'sandro-paris.com',
    'maje.com',
    'claudiepierlot.com',
    'ba&sh.com',
    'zadig-et-voltaire.com',
    'moncler.com',

    // Джинсовая одежда
    'levi.com',
    'wrangler.com',
    'lee.com',
    'diesel.com',
    'g-star.com',
    '7forallmankind.com',
    'true-religion.com',
    'joesjeans.com',
    'paige.com',
    'frame-la.com',
    'motherdenim.com',
    'agolde.com',
    'citizensofhumanity.com',
    'madewell.com',

    // Белье
    'victoriassecret.com',
    'agentprovocateur.com',
    'laperla.com',
    'chantelle.com',
    'simoneperele.com',
    'prima-donna.eu',
    'triumph.com',
    'wacaolingerie.com',
    'caresse.fr',

    // Премиум
    'tommy.com',
    'calvinklein.com',
    'lacoste.com',
    'ralphlauren.com',
    'chanel.com',
    'dior.com',
    'gucci.com',
    'prada.com',
    'versace.com',
    'armani.com',
    'burberry.com',
    'fendi.com',
    'loewe.com',
    'bottegaveneta.com',
    'balenciaga.com',
    'saintlaurent.com',
    'givenchy.com',
    'valentino.com',
    'miumiu.com',
    'lanvin.com',
    'celine.com',
    'hermes.com',
    'louisvuitton.com',

    // Обувь
    'converse.com',
    'vans.com',
    'timberland.com',
    'drmartens.com',
    'skechers.com',
    'crocs.com',
    'christianlouboutin.com',
    'manoloblahnik.com',
    'jimmychoo.com',
    'gianvitorossi.com',
    'aquazzura.com',
    'roger-vivier.com',
    'sergio-rossi.com',
    'renzocaovilla.com',
    'giuseppezanotti.com',
    'prives.com',

    // Сумки и аксессуары
    'mulberry.com',
    'strathberry.com',
    'polene-paris.com',
    'mansurgavriel.com',
    'demellier.com',
    'staud.co',
    'byfar.com',
    'jwpei.com',
    'auper.com',
    'cuyana.com',
    'everlane.com',

    // ===== ДОМ И ДЕКОР =====
    'ikea.com',
    'westelm.com',
    'crateandbarrel.com',
    'potterybarn.com',
    'anthropologie.com',
    'urbanoutfitters.com',
    'zarahome.com',
    'leroymerlin.ru',
    'obi.ru',
    'petrovich.ru',
    'vseinstrumenti.ru',
    '220-volt.ru',
    'tvoi-dom.ru',
    'stroyka.by',
    'krysha.by',
    'realt.by',
    'metrika.by',

    // ===== КОСМЕТИКА И ПАРФЮМ =====
    'sephora.com',
    'ulta.com',
    'nyxcosmetics.com',
    'maccosmetics.com',
    'loccitane.com',
    'thebodyshop.com',
    'kiehls.com',
    'glossier.com',
    'fentybeauty.com',
    'esteelauder.com',
    'clinique.com',
    'lancome.com',
    'lamer.com',
    'bobbibrown.com',
    'shuuemura.com',
    'makeupforever.com',
    'urban-decay.com',
    'toofaced.com',
    'tartecosmetics.com',
    'nars.com',
    'benefitcosmetics.com',
    'smashbox.com',
    'itcosmetics.com',
    'innisfree.com',
    'etudehouse.com',
    'cosrx.com',
    'klairs.com',
    'purito.com',
    'sokoglam.com',
    'yesstyle.com',
    'stylekorean.com',
    'oliveyoung.com',
    'letual.ru',
    'rivgosh.ru',
    'goldapple.ru',
    'domkosmetiki.ru',
    'cosmetique.ru',
    'rosebeauty.ru',

    // ===== УКРАШЕНИЯ =====
    'pandora.net',
    'swarovski.com',
    'tiffany.com',
    'cartier.com',
    'sunlight.net',
    '585zolotoy.ru',
    'yashma.ru',
    'chopard.com',
    'bulgari.com',
    'van-cleef-arpels.com',
    'piaget.com',
    'jaeger-lecoultre.com',
    'omega.com',
    'rolex.com',
    'tagheuer.com',
    'longines.com',
    'breitling.com',
    'seikowatches.com',
    'citizenwatch.com',
    'fossil.com',
    'danielwellington.com',
    'adamas.ru',
    'sokolov.ru',
    'brilliant.ru',
    'alrosa.ru',
    'korloff.ru',

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
    'start.ru',
    'more.tv',
    'amediateka.ru',

    // ===== IT / ДИЗАЙН =====
    'github.com',
    'figma.com',
    'behance.net',
    'dribbble.com',
    'artstation.com',
    'gitlab.com',
    'codepen.io',
    'stackoverflow.com',
    'sketch.com',
    'adobe.com',
    'adobe.io',
    'creativecloud.adobe.com',
    'spline.design',

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
    'ubisoft.com',
    'ea.com',
    'rockstargames.com',
    'blizzard.com',
    'riotgames.com',
    'valvesoftware.com',
    'cdprojektred.com',
    'bandainamco.com',
    'sega.com',
    'capcom.com',
    'square-enix.com',
    'konami.com',
    'eslgaming.com',
    'dreamhack.com',
    'faceit.com',
    'gosugamers.com',
    'cybersport.ru',
    'ggscore.com',
    'scoreboard.com',
    'esea.net',

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
    'sciencedirect.com',
    'jstor.org',
    'academia.edu',
    'researchgate.net',
    'ieee.org',
    'springer.com',
    'elsevier.com',
    'wiley.com',
    'domashka.ru',
    'znanija.com',
    'multiurok.ru',
    'infourok.ru',
    'proshkolu.ru',
    'logiclike.com',
    'brainpop.com',
    'abcmouse.com',
    'starfall.com',
    'pbskids.org',
    'getcourse.ru',
    'teachable.com',
    'thinkific.com',
    'foxford.ru',
    'lecta.ru',
    'uchi.ru',
    'reshaem.ru',
    'nsportal.ru',
    'solverschool.ru',
    'math-solution.ru',
    'edumentor.ru',

    // ===== ФОТО =====
    'unsplash.com',
    'pexels.com',
    'shutterstock.com',
    '500px.com',
    'flickr.com',
    'vsco.co',
    'smugmug.com',
    'photobucket.com',
    'imgur.com',
    'giphy.com',
    'tenor.com',

    // ===== ДРУГОЕ =====
    'notion.so',
    'miro.com',
    'canva.com',
    'medium.com',
    'substack.com',

    // ===== ССЫЛКИ ДЛЯ ТВОРЦОВ =====
    'linktr.ee',
    'beacons.ai',
    'milkshake.app',
    'carrd.co',
    'bio.link',
    'linkin.bio',
    'snipfeed.co',
    'lumen5.com',
    'headliner.app',
    'repurpos.io',

    // ===== ПОИСКОВИКИ И КАРТЫ =====
    'yandex.com',
    'yandex.ru',
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
    'binance.com',
    'bybit.com',
    'okx.com',
    'coinmarketcap.com',
    'coingecko.com',
    'dexscreener.com',
    'bitcoin.com',
    'ethereum.org',
    'solana.com',

    // ===== КРИПТО И WEB3 =====
    'opensea.io',
    'rarible.com',
    'foundation.app',
    'superrare.co',
    'zora.co',

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
    'blablacar.ru',
    'trivago.com',
    'one-two-trip.ru',
    'travelata.ru',
    'poezd.ru',
    'busfor.ru',
    'flixbus.com',
    'omio.com',
    'rome2rio.com',
    'timepad.ru',
    'leader-id.ru',
    'eventbrite.com',

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
    'yandex.health',
    'medsi.ru',
    'mosgorzdrav.ru',
    'doctor.rf',
    'sberhealth.ru',

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
    'strava.com',
    'myfitnesspal.com',
    'fatsecret.ru',
    'healthline.com',
    'bodybuilding.com',
    'muscleandfitness.com',
    'citysport.ru',
    'goldsgym.com',
    'fitness24.ru',

    // ===== ДЕТСКИЕ ТОВАРЫ =====
    'pocemu4ek.ru',
    'korablik.ru',
    'mothercare.com',
    'hamleys.com',
    'mirkubikov.ru',
    'babyzzz.ru',
    'detskayaliniya.ru',
    'detskaya-mechta.ru',
    'mamashop.ru',
    'pampers.ru',
    'huggies.ru',
    'babylove.ru',
    'baby.ru',
    'mamaclub.ru',
    'beremennost.com',
    'pregnancy.com',
    'whattoexpect.com',
    'parents.com',
    'mishka-online.ru',

    // ===== ЗООТОВАРЫ =====
    'zoomagazin.ru',
    'betkhoven.ru',
    '4lapy.ru',
    'chewy.com',
    'petco.com',
    'petsmart.com',
    'zoopassage.ru',
    'zoobazar.ru',
    'zoogurman.ru',
    'zoobonus.ru',
    'kormushka.ru',
    'vetclinic.ru',
    'zoovet.ru',
    'vetcity.ru',
    'vetdoctor.ru',
    'petmd.com',
    'vetstreet.com',
    'pawshake.com',
    'bringfido.com',
    'rover.com',
    'wagwalking.com',

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
    'foodgawker.com',
    'taste.com.au',
    'bbcgoodfood.com',
    'delish.com',
    'bonappetit.com',
    'epicurious.com',
    'seriouseats.com',
    'smittenkitchen.com',

    // ===== ТВОРЧЕСТВО =====
    'leonardo.ru',
    'peredvizhnik.ru',
    'artfox.ru',
    'craftsy.com',
    'lovecrafts.com',
    'purlsoho.com',
    'weareknitters.com',
    'woolwarehouse.co.uk',
    'deramores.com',
    'sheepandstitch.com',
    'beadworld.ru',
    'biserok.ru',

    // ===== ЖЕНСКИЕ СЕРВИСЫ И МЕДИА =====
    'cosmopolitan.ru',
    'elle.ru',
    'vogue.ru',
    'tatler.ru',
    'harpersbazaar.ru',
    'grazia.ru',
    'glamour.ru',
    'marieclaire.ru',
    'instyle.ru',
    'makeup.ru',
    'beautyinsider.ru',
    'wedding.ru',
    'svadba-online.ru',
    'wedding.com',
    'theknot.com',
    'brides.com',
    'weddingwire.com',
    'lavanda.media',
    'psychologies.ru',
    'urokiburuma.ru',
    'puzzle-english.com',
    'mel.fm',
    'ledy.mail.ru',
    'woman.ru',
    'mamlife.ru',
    '7ya.ru',
    'u-mama.ru',
    'babyblog.ru',
    'koshechka.ru',
    'livemaster.ru',
    'yarmarka-masterov.ru',

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
    'womansworld.com',

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
    'glassdoor.com',
    'indeed.com',
    'monster.com',
    'careerbuilder.com',
    'simplyhired.com',
    'ziprecruiter.com',

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
    'avtopro.ru',
    'exist.ru',
    'emex.ru',

    // ===== НЕДВИЖИМОСТЬ =====
    'domofond.ru',
    'm2.ru',

    // ===== КИНО И БИЛЕТЫ =====
    'afisha.ru',
    'ticketland.ru',
    'bilet.ru',
    'karabas.com',
    'kinoteatr.ru',
    'ticketco.ru',
    'teatr.ru',
    'museum.ru',
    'kino-teatr.ru',

    // ===== ПОЧТА =====
    'gmail.com',
    'mail.ru',
    'outlook.com',
    'protonmail.com',

    // ===== ВИДЕОКОНФЕРЕНЦИИ =====
    'zoom.us',
    'webex.com',
    'teams.microsoft.com',
    'skype.com',
    'slack.com',
    'mattermost.com',
    'google.classroom',
    'microsoft.teams',

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

    // ===== ЗНАКОМСТВА =====
    'tinder.com',
    'bumble.com',
    'happn.com',
    'hinge.co',
    'pof.com',
    'okcupid.com',
    'feeld.co',
    'her.com',
    'taimi.com',
    'mamba.ru',
    'teamo.ru',
    'loveplanet.ru',
    'dating.ru',

    // ===== БРЕНДЫ ТЕХНИКИ =====
    'samsung.com',
    'xiaomi.com',
    'huawei.com',
    'sony.com',
    'lg.com',
    'philips.com',
    'panasonic.com',
    'canon.com',
    'nikon.com',
    'gopro.com',
    'dji.com',
    'insta360.com',

    // ===== МОБИЛЬНЫЕ ПЛАТФОРМЫ =====
    'appstore.com',
    'play.google.com',
    'appgallery.com',
    'galaxystore.com',
    'appadvice.com',
    'sensortower.com',
    'appannie.com',

    // ===== НЕЙРОСЕТИ И AI =====
    'openai.com',
    'chat.openai.com',
    'midjourney.com',
    'stability.ai',
    'runwayml.com',
    'pika.art',
    'leonardo.ai',
    'clipdrop.co',
    'remover.app',
    'photoroom.com',
    'remove.bg',
    'cleanup.pictures',
    'perplexity.ai',
    'claude.ai',
    'gemini.google.com',
    'mistral.ai',
    'deepseek.com',
    'qwen.ai',
    'grok.x.com',
    'you.com',
    'phind.com',
    'poe.com',
    'character.ai',
    'replika.com',
    'pi.ai',

    // ===== ПОДКАСТЫ =====
    'podcast.ru',
    'glow.fm',
    'transistor.fm',
    'fable.co',
    'podster.fm',
    'podfm.ru',
    'yandex.music/podcast',
    'apple.com/podcast',
    'podcasts.google.com',
    'spotify.com/podcast',
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
        'chanel.',
        'dior.',
        'gucci.',
        'prada.',
        'versace.',
        'armani.',
        'burberry.',
        'fendi.',
        'loewe.',
        'bottegaveneta.',
        'balenciaga.',
        'saintlaurent.',
        'givenchy.',
        'valentino.',
        'miumiu.',
        'lanvin.',
        'celine.',
        'hermes.',
        'louisvuitton.',
        'christianlouboutin.',
        'manoloblahnik.',
        'jimmychoo.',
        'gianvitorossi.',
        'aquazzura.',
        'roger-vivier.',
        'sergio-rossi.',
        'renzocaovilla.',
        'giuseppezanotti.',
        'mulberry.',
        'strathberry.',
        'polene-paris.',
        'mansurgavriel.',
        'demellier.',
        'estee',
        'clinique.',
        'lancome.',
        'lamer.',
        'bobbibrown.',
        'shuuemura.',
        'makeupforever.',
        'urban-decay.',
        'toofaced.',
        'tartecosmetics.',
        'nars.',
        'benefitcosmetics.',
        'smashbox.',
        'itcosmetics.',
        'innisfree.',
        'etudehouse.',
        'cosrx.',
        'klairs.',
        'purito.',
        'sokoglam.',
        'yesstyle.',
        'stylekorean.',
        'oliveyoung.',
        'letual.',
        'rivgosh.',
        'goldapple.',
        'domkosmetiki.',
        'cosmetique.',
        'rosebeauty.',
        'chopard.',
        'bulgari.',
        'van-cleef-arpels.',
        'piaget.',
        'jaeger-lecoultre.',
        'omega.',
        'rolex.',
        'tagheuer.',
        'longines.',
        'breitling.',
        'seikowatches.',
        'citizenwatch.',
        'fossil.',
        'danielwellington.',
        'adamas.',
        'sokolov.',
        'brilliant.',
        'alrosa.',
        'korloff.',
        'openai.',
        'midjourney.',
        'stability.ai',
        'runwayml.',
        'pika.art',
        'leonardo.ai',
        'perplexity.ai',
        'claude.ai',
        'deepseek.',
        'character.ai',
        'replika.',
        'podcast.',
        'glow.fm',
        'transistor.fm',
        'fable.co',
        'podster.',
        'patreon.',
        'boosty.to',
        'donationalerts.',
        'buymeacoffee.',
        'ko-fi.com',
        'gumroad.',
        'stan.store',
        'whop.com',
        'redbubble.',
        'society6.',
        'teepublic.',
        'printful.',
        'printify.',
        'beacons.ai',
        'carrd.co',
        'linktr.ee',
        'milkshake.app',
        'snipfeed.co',
        'kick.com',
        'rumble.com',
        'odysee.com',
        'clapper.tv',
        'triller.com',
        'opensea.io',
        'rarible.com',
        'foundation.app',
        'superrare.co',
        'binance.com',
        'bybit.com',
        'okx.com',
        'coinmarketcap.com',
        'coingecko.com',
        'foxford.ru',
        'uchi.ru',
        'mel.fm',
        'woman.ru',
        '7ya.ru',
        'babyblog.ru',
        'livemaster.ru',
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
    if (lower.contains('distrokid.com')) return 'distrokid';
    if (lower.contains('tunecore.com')) return 'tunecore';
    if (lower.contains('cdbaby.com')) return 'cdbaby';
    if (lower.contains('amuse.io')) return 'amuse';
    if (lower.contains('bandlab.com')) return 'bandlab';
    if (lower.contains('soundtrap.com')) return 'soundtrap';
    if (lower.contains('landr.com')) return 'landr';
    if (lower.contains('mastering.com')) return 'mastering';

    // ---- ВИДЕО ----
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) return 'youtube';
    if (lower.contains('vimeo.com')) return 'vimeo';
    if (lower.contains('twitch.tv')) return 'twitch';
    if (lower.contains('bilibili.com')) return 'bilibili';
    if (lower.contains('dailymotion.com')) return 'dailymotion';
    if (lower.contains('likee.com')) return 'likee';
    if (lower.contains('kwai.com')) return 'kwai';
    if (lower.contains('mojo.com')) return 'mojo';
    if (lower.contains('kick.com')) return 'kick';
    if (lower.contains('rumble.com')) return 'rumble';
    if (lower.contains('odysee.com')) return 'odysee';
    if (lower.contains('clapper.tv')) return 'clapper';
    if (lower.contains('triller.com')) return 'triller';
    if (lower.contains('firework.com')) return 'firework';
    if (lower.contains('clipchamp.com')) return 'clipchamp';

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
    if (lower.contains('threads.net')) return 'threads';
    if (lower.contains('bluesky.social')) return 'bluesky';
    if (lower.contains('mastodon.social')) return 'mastodon';
    if (lower.contains('clubhouse.com')) return 'clubhouse';
    if (lower.contains('ok.ru')) return 'ok';
    if (lower.contains('dzen.ru')) return 'dzen';
    if (lower.contains('habr.com')) return 'habr';
    if (lower.contains('vc.ru')) return 'vc';
    if (lower.contains('pikabu.ru')) return 'pikabu';
    if (lower.contains('be.real')) return 'bereal';
    if (lower.contains('weverse.io')) return 'weverse';
    if (lower.contains('sarafan.ru')) return 'sarafan';
    if (lower.contains('livejournal.com')) return 'livejournal';

    // ---- ПЛАТФОРМЫ ДЛЯ ТВОРЦОВ ----
    if (lower.contains('patreon.com')) return 'patreon';
    if (lower.contains('boosty.to')) return 'boosty';
    if (lower.contains('donationalerts.com')) return 'donationalerts';
    if (lower.contains('buymeacoffee.com')) return 'buymeacoffee';
    if (lower.contains('ko-fi.com')) return 'kofi';
    if (lower.contains('gumroad.com')) return 'gumroad';
    if (lower.contains('stan.store')) return 'stan';
    if (lower.contains('whop.com')) return 'whop';

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
    if (lower.contains('megamarket.ru')) return 'megamarket';
    if (lower.contains('market.yandex.ru')) return 'yandex_market';
    if (lower.contains('goods.ru')) return 'goods';
    if (lower.contains('sbermarket.ru')) return 'sbermarket';

    // ---- ПЛАТФОРМЫ ДЛЯ МЕРЧА ----
    if (lower.contains('redbubble.com')) return 'redbubble';
    if (lower.contains('society6.com')) return 'society6';
    if (lower.contains('teepublic.com')) return 'teepublic';
    if (lower.contains('printful.com')) return 'printful';
    if (lower.contains('printify.com')) return 'printify';
    if (lower.contains('merch.amazon.com')) return 'amazon_merch';

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
    if (lower.contains('levi.com')) return 'levi';
    if (lower.contains('converse.com')) return 'converse';
    if (lower.contains('vans.com')) return 'vans';
    if (lower.contains('timberland.com')) return 'timberland';
    if (lower.contains('drmartens.com')) return 'drmartens';
    if (lower.contains('skechers.com')) return 'skechers';
    if (lower.contains('crocs.com')) return 'crocs';
    if (lower.contains('massimodutti.com')) return 'massimodutti';
    if (lower.contains('oysho.com')) return 'oysho';
    if (lower.contains('moncler.com')) return 'moncler';
    if (lower.contains('victoriassecret.com')) return 'victoriassecret';

    // ---- ПРЕМИУМ БРЕНДЫ ----
    if (lower.contains('chanel.com')) return 'chanel';
    if (lower.contains('dior.com')) return 'dior';
    if (lower.contains('gucci.com')) return 'gucci';
    if (lower.contains('prada.com')) return 'prada';
    if (lower.contains('versace.com')) return 'versace';
    if (lower.contains('armani.com')) return 'armani';
    if (lower.contains('burberry.com')) return 'burberry';
    if (lower.contains('fendi.com')) return 'fendi';
    if (lower.contains('loewe.com')) return 'loewe';
    if (lower.contains('bottegaveneta.com')) return 'bottega';
    if (lower.contains('balenciaga.com')) return 'balenciaga';
    if (lower.contains('saintlaurent.com')) return 'saintlaurent';
    if (lower.contains('givenchy.com')) return 'givenchy';
    if (lower.contains('valentino.com')) return 'valentino';
    if (lower.contains('miumiu.com')) return 'miumiu';
    if (lower.contains('celine.com')) return 'celine';
    if (lower.contains('hermes.com')) return 'hermes';
    if (lower.contains('louisvuitton.com')) return 'louisvuitton';

    // ---- ОБУВЬ ----
    if (lower.contains('christianlouboutin.com')) return 'louboutin';
    if (lower.contains('manoloblahnik.com')) return 'manoloblahnik';
    if (lower.contains('jimmychoo.com')) return 'jimmychoo';
    if (lower.contains('gianvitorossi.com')) return 'gianvitorossi';
    if (lower.contains('aquazzura.com')) return 'aquazzura';
    if (lower.contains('roger-vivier.com')) return 'rogervivier';
    if (lower.contains('sergio-rossi.com')) return 'sergiorossi';
    if (lower.contains('giuseppezanotti.com')) return 'giuseppezanotti';

    // ---- СУМКИ И АКСЕССУАРЫ ----
    if (lower.contains('mulberry.com')) return 'mulberry';
    if (lower.contains('strathberry.com')) return 'strathberry';
    if (lower.contains('polene-paris.com')) return 'polene';
    if (lower.contains('mansurgavriel.com')) return 'mansurgavriel';
    if (lower.contains('demellier.com')) return 'demellier';
    if (lower.contains('cuyana.com')) return 'cuyana';
    if (lower.contains('everlane.com')) return 'everlane';

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
    if (lower.contains('esteelauder.com')) return 'esteelauder';
    if (lower.contains('clinique.com')) return 'clinique';
    if (lower.contains('lancome.com')) return 'lancome';
    if (lower.contains('lamer.com')) return 'lamer';
    if (lower.contains('bobbibrown.com')) return 'bobbibrown';
    if (lower.contains('shuuemura.com')) return 'shuuemura';
    if (lower.contains('makeupforever.com')) return 'makeupforever';
    if (lower.contains('urban-decay.com')) return 'urbandecay';
    if (lower.contains('toofaced.com')) return 'toofaced';
    if (lower.contains('tartecosmetics.com')) return 'tarte';
    if (lower.contains('nars.com')) return 'nars';
    if (lower.contains('benefitcosmetics.com')) return 'benefit';
    if (lower.contains('innisfree.com')) return 'innisfree';
    if (lower.contains('etudehouse.com')) return 'etudehouse';
    if (lower.contains('cosrx.com')) return 'cosrx';
    if (lower.contains('sokoglam.com')) return 'sokoglam';
    if (lower.contains('yesstyle.com')) return 'yesstyle';
    if (lower.contains('letual.ru')) return 'letual';
    if (lower.contains('rivgosh.ru')) return 'rivgosh';
    if (lower.contains('goldapple.ru')) return 'goldapple';

    // ---- УКРАШЕНИЯ ----
    if (lower.contains('pandora.net')) return 'pandora';
    if (lower.contains('swarovski.com')) return 'swarovski';
    if (lower.contains('tiffany.com')) return 'tiffany';
    if (lower.contains('cartier.com')) return 'cartier';
    if (lower.contains('sunlight.net')) return 'sunlight';
    if (lower.contains('585zolotoy.ru')) return 'zolotoy585';
    if (lower.contains('yashma.ru')) return 'yashma';
    if (lower.contains('chopard.com')) return 'chopard';
    if (lower.contains('bulgari.com')) return 'bulgari';
    if (lower.contains('van-cleef-arpels.com')) return 'vancleef';
    if (lower.contains('adamas.ru')) return 'adamas';
    if (lower.contains('sokolov.ru')) return 'sokolov';

    // ---- ССЫЛКИ ДЛЯ ТВОРЦОВ ----
    if (lower.contains('linktr.ee')) return 'linktree';
    if (lower.contains('beacons.ai')) return 'beacons';
    if (lower.contains('carrd.co')) return 'carrd';
    if (lower.contains('milkshake.app')) return 'milkshake';
    if (lower.contains('snipfeed.co')) return 'snipfeed';

    // ---- ЕДА ----
    if (lower.contains('lavka.yandex.ru')) return 'yandex_lavka';
    if (lower.contains('sbermarket.ru')) return 'sbermarket';
    if (lower.contains('fresh.ozon.ru')) return 'ozon_fresh';
    if (lower.contains('vkusvill.ru')) return 'vkusvill';
    if (lower.contains('dodopizza.ru')) return 'dodopizza';
    if (lower.contains('sushiwok.ru')) return 'sushiwok';
    if (lower.contains('tanuki.ru')) return 'tanuki';
    if (lower.contains('yakitoriya.ru')) return 'yakitoriya';
    if (lower.contains('eda.ru')) return 'eda';

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
    if (lower.contains('strava.com')) return 'strava';
    if (lower.contains('myfitnesspal.com')) return 'myfitnesspal';

    // ---- ДЕТСКИЕ ТОВАРЫ ----
    if (lower.contains('pocemu4ek.ru')) return 'pocemu4ek';
    if (lower.contains('korablik.ru')) return 'korablik';
    if (lower.contains('mothercare.com')) return 'mothercare';
    if (lower.contains('hamleys.com')) return 'hamleys';
    if (lower.contains('mirkubikov.ru')) return 'mirkubikov';
    if (lower.contains('baby.ru')) return 'babyru';
    if (lower.contains('mamaclub.ru')) return 'mamaclub';
    if (lower.contains('whattoexpect.com')) return 'whattoexpect';
    if (lower.contains('parents.com')) return 'parents';
    if (lower.contains('mishka-online.ru')) return 'mishka';

    // ---- ЗООТОВАРЫ ----
    if (lower.contains('zoomagazin.ru')) return 'zoomagazin';
    if (lower.contains('betkhoven.ru')) return 'betkhoven';
    if (lower.contains('4lapy.ru')) return 'lapy4';
    if (lower.contains('chewy.com')) return 'chewy';
    if (lower.contains('petco.com')) return 'petco';
    if (lower.contains('petsmart.com')) return 'petsmart';
    if (lower.contains('petmd.com')) return 'petmd';

    // ---- ТВОРЧЕСТВО ----
    if (lower.contains('leonardo.ru')) return 'leonardo';
    if (lower.contains('peredvizhnik.ru')) return 'peredvizhnik';
    if (lower.contains('artfox.ru')) return 'artfox';
    if (lower.contains('craftsy.com')) return 'craftsy';
    if (lower.contains('lovecrafts.com')) return 'lovecrafts';

    // ---- ЖЕНСКИЕ СЕРВИСЫ ----
    if (lower.contains('cosmopolitan.ru')) return 'cosmopolitan';
    if (lower.contains('elle.ru')) return 'elle';
    if (lower.contains('vogue.ru')) return 'vogue';
    if (lower.contains('harpersbazaar.ru')) return 'harpersbazaar';
    if (lower.contains('grazia.ru')) return 'grazia';
    if (lower.contains('glamour.ru')) return 'glamour';
    if (lower.contains('marieclaire.ru')) return 'marieclaire';
    if (lower.contains('instyle.ru')) return 'instyle';
    if (lower.contains('wedding.ru')) return 'weddingru';
    if (lower.contains('theknot.com')) return 'theknot';
    if (lower.contains('brides.com')) return 'brides';
    if (lower.contains('lavanda.media')) return 'lavanda';
    if (lower.contains('psychologies.ru')) return 'psychologies';
    if (lower.contains('mel.fm')) return 'mel';
    if (lower.contains('woman.ru')) return 'woman';
    if (lower.contains('mamlife.ru')) return 'mamlife';
    if (lower.contains('7ya.ru')) return '7ya';
    if (lower.contains('u-mama.ru')) return 'umama';
    if (lower.contains('babyblog.ru')) return 'babyblog';
    if (lower.contains('livemaster.ru')) return 'livemaster';

    // ---- ОБРАЗОВАНИЕ ----
    if (lower.contains('foxford.ru')) return 'foxford';
    if (lower.contains('uchi.ru')) return 'uchi';
    if (lower.contains('getcourse.ru')) return 'getcourse';
    if (lower.contains('teachable.com')) return 'teachable';
    if (lower.contains('thinkific.com')) return 'thinkific';

    // ---- НЕЙРОСЕТИ ----
    if (lower.contains('openai.com') || lower.contains('chat.openai.com')) return 'openai';
    if (lower.contains('midjourney.com')) return 'midjourney';
    if (lower.contains('stability.ai')) return 'stability';
    if (lower.contains('runwayml.com')) return 'runway';
    if (lower.contains('pika.art')) return 'pika';
    if (lower.contains('leonardo.ai')) return 'leonardo_ai';
    if (lower.contains('perplexity.ai')) return 'perplexity';
    if (lower.contains('claude.ai')) return 'claude';
    if (lower.contains('deepseek.com')) return 'deepseek';
    if (lower.contains('character.ai')) return 'character';
    if (lower.contains('replika.com')) return 'replika';

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
    if (lower.contains('adobe.com')) return 'adobe';
    if (lower.contains('creativecloud.adobe.com')) return 'adobe_cc';

    // ---- ИГРЫ ----
    if (lower.contains('steampowered.com') || lower.contains('store.steampowered.com')) return 'steam';
    if (lower.contains('epicgames.com')) return 'epic';
    if (lower.contains('gog.com')) return 'gog';
    if (lower.contains('itch.io')) return 'itch';
    if (lower.contains('playstation.com')) return 'playstation';
    if (lower.contains('xbox.com')) return 'xbox';
    if (lower.contains('nintendo.com')) return 'nintendo';
    if (lower.contains('battle.net')) return 'battlenet';
    if (lower.contains('ubisoft.com')) return 'ubisoft';
    if (lower.contains('ea.com')) return 'ea';
    if (lower.contains('rockstargames.com')) return 'rockstar';
    if (lower.contains('riotgames.com')) return 'riot';
    if (lower.contains('cybersport.ru')) return 'cybersport';
    if (lower.contains('faceit.com')) return 'faceit';
    if (lower.contains('ggscore.com')) return 'ggscore';

    // ---- КРИПТО ----
    if (lower.contains('opensea.io')) return 'opensea';
    if (lower.contains('rarible.com')) return 'rarible';
    if (lower.contains('foundation.app')) return 'foundation';
    if (lower.contains('superrare.co')) return 'superrare';
    if (lower.contains('binance.com')) return 'binance';
    if (lower.contains('bybit.com')) return 'bybit';
    if (lower.contains('okx.com')) return 'okx';
    if (lower.contains('coinmarketcap.com')) return 'coinmarketcap';
    if (lower.contains('coingecko.com')) return 'coingecko';

    // ---- КНИГИ ----
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
    if (lower.contains('500px.com')) return '500px';
    if (lower.contains('flickr.com')) return 'flickr';
    if (lower.contains('vsco.co')) return 'vsco';
    if (lower.contains('imgur.com')) return 'imgur';
    if (lower.contains('giphy.com')) return 'giphy';

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

    // ---- БРОНИРОВАНИЕ ----
    if (lower.contains('booking.com')) return 'booking';
    if (lower.contains('agoda.com')) return 'agoda';
    if (lower.contains('airbnb.com')) return 'airbnb';
    if (lower.contains('tripadvisor.com')) return 'tripadvisor';
    if (lower.contains('skyscanner.net')) return 'skyscanner';
    if (lower.contains('kiwi.com')) return 'kiwi';
    if (lower.contains('expedia.com')) return 'expedia';
    if (lower.contains('kayak.com')) return 'kayak';
    if (lower.contains('hostelworld.com')) return 'hostelworld';
    if (lower.contains('aviasales.ru')) return 'aviasales';
    if (lower.contains('tutu.ru')) return 'tutu';
    if (lower.contains('blablacar.ru')) return 'blablacar';
    if (lower.contains('trivago.com')) return 'trivago';
    if (lower.contains('one-two-trip.ru')) return 'onetwotrip';
    if (lower.contains('timepad.ru')) return 'timepad';
    if (lower.contains('eventbrite.com')) return 'eventbrite';

    // ---- ЗДОРОВЬЕ ----
    if (lower.contains('webmd.com')) return 'webmd';
    if (lower.contains('mayoclinic.org')) return 'mayoclinic';
    if (lower.contains('nhs.uk')) return 'nhs';
    if (lower.contains('apteka.ru')) return 'apteka';
    if (lower.contains('zdravcity.ru')) return 'zdravcity';
    if (lower.contains('iherb.com')) return 'iherb';
    if (lower.contains('docdoc.ru')) return 'docdoc';
    if (lower.contains('yandex.health')) return 'yandex_health';

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
    if (lower.contains('foodpanda.com')) return 'foodpanda';
    if (lower.contains('talabat.com')) return 'talabat';
    if (lower.contains('zomato.com')) return 'zomato';
    if (lower.contains('swiggy.com')) return 'swiggy';

    // ---- ТАКСИ ----
    if (lower.contains('uber.com')) return 'uber';
    if (lower.contains('lyft.com')) return 'lyft';
    if (lower.contains('gett.com')) return 'gett';
    if (lower.contains('getaround.com')) return 'getaround';
    if (lower.contains('sharenow.com')) return 'sharenow';
    if (lower.contains('citymobil.ru')) return 'citymobil';

    // ---- РАБОТА ----
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
    if (lower.contains('upwork.com')) return 'upwork';
    if (lower.contains('freelancer.com')) return 'freelancer';
    if (lower.contains('fiverr.com')) return 'fiverr';
    if (lower.contains('toptal.com')) return 'toptal';
    if (lower.contains('glassdoor.com')) return 'glassdoor';
    if (lower.contains('indeed.com')) return 'indeed';
    if (lower.contains('monster.com')) return 'monster';

    // ---- АВТО ----
    if (lower.contains('avtocod.ru')) return 'avtocod';
    if (lower.contains('drom.ru')) return 'drom';
    if (lower.contains('auto.ru')) return 'auto';
    if (lower.contains('avtorun.ru')) return 'avtorun';
    if (lower.contains('drive2.ru')) return 'drive2';
    if (lower.contains('avtopro.ru')) return 'avtopro';
    if (lower.contains('exist.ru')) return 'exist';
    if (lower.contains('emex.ru')) return 'emex';

    // ---- ТЕХНИКА ----
    if (lower.contains('samsung.com')) return 'samsung';
    if (lower.contains('xiaomi.com')) return 'xiaomi';
    if (lower.contains('huawei.com')) return 'huawei';
    if (lower.contains('sony.com')) return 'sony';
    if (lower.contains('lg.com')) return 'lg';
    if (lower.contains('philips.com')) return 'philips';
    if (lower.contains('canon.com')) return 'canon';
    if (lower.contains('nikon.com')) return 'nikon';
    if (lower.contains('gopro.com')) return 'gopro';
    if (lower.contains('dji.com')) return 'dji';

    // ---- ЯНДЕКС-СЕРВИСЫ ----
    if (lower.contains('eda.yandex.ru') || lower.contains('food.yandex.ru')) return 'yandex_eda';
    if (lower.contains('taxi.yandex.ru')) return 'yandex_taxi';
    if (lower.contains('drive.yandex.ru')) return 'yandex_drive';

    // ---- ЗНАКОМСТВА ----
    if (lower.contains('tinder.com')) return 'tinder';
    if (lower.contains('bumble.com')) return 'bumble';
    if (lower.contains('mamba.ru')) return 'mamba';
    if (lower.contains('teamo.ru')) return 'teamo';
    if (lower.contains('dating.ru')) return 'dating';

    // ---- ПОДКАСТЫ ----
    if (lower.contains('podcast.ru')) return 'podcastru';
    if (lower.contains('podster.fm')) return 'podster';
    if (lower.contains('podfm.ru')) return 'podfm';
    if (lower.contains('glow.fm')) return 'glow';
    if (lower.contains('transistor.fm')) return 'transistor';

    // ---- НОВОСТИ ----
    if (lower.contains('bbc.com') || lower.contains('bbc.co.uk')) return 'bbc';
    if (lower.contains('cnn.com')) return 'cnn';
    if (lower.contains('nytimes.com')) return 'nytimes';
    if (lower.contains('wsj.com')) return 'wsj';
    if (lower.contains('forbes.com') || lower.contains('forbes.ru')) return 'forbes';
    if (lower.contains('bloomberg.com')) return 'bloomberg';
    if (lower.contains('ft.com')) return 'ft';
    if (lower.contains('economist.com')) return 'economist';
    if (lower.contains('wired.com')) return 'wired';
    if (lower.contains('techcrunch.com')) return 'techcrunch';
    if (lower.contains('theverge.com')) return 'theverge';
    if (lower.contains('cnet.com')) return 'cnet';
    if (lower.contains('gizmodo.com')) return 'gizmodo';
    if (lower.contains('mashable.com')) return 'mashable';
    if (lower.contains('buzzfeed.com')) return 'buzzfeed';
    if (lower.contains('huffpost.com')) return 'huffpost';
    if (lower.contains('vox.com')) return 'vox';
    if (lower.contains('politico.com')) return 'politico';
    if (lower.contains('axios.com')) return 'axios';
    if (lower.contains('businessinsider.com')) return 'businessinsider';
    if (lower.contains('fastcompany.com')) return 'fastcompany';
    if (lower.contains('inc.com')) return 'inc';
    if (lower.contains('entrepreneur.com')) return 'entrepreneur';
    if (lower.contains('hbr.org')) return 'hbr';
    if (lower.contains('nationalgeographic.com')) return 'natgeo';
    if (lower.contains('nature.com')) return 'nature';
    if (lower.contains('sciencemag.org')) return 'sciencemag';
    if (lower.contains('pnas.org')) return 'pnas';
    if (lower.contains('sciencedaily.com')) return 'sciencedaily';
    if (lower.contains('livescience.com')) return 'livescience';
    if (lower.contains('phys.org')) return 'phys';
    if (lower.contains('popularmechanics.com')) return 'popularmechanics';
    if (lower.contains('engadget.com')) return 'engadget';
    if (lower.contains('arstechnica.com')) return 'arstechnica';
    if (lower.contains('zdnet.com')) return 'zdnet';
    if (lower.contains('rt.com')) return 'rt';
    if (lower.contains('tass.ru')) return 'tass';
    if (lower.contains('ria.ru')) return 'ria';
    if (lower.contains('lenta.ru')) return 'lenta';
    if (lower.contains('gazeta.ru')) return 'gazeta';
    if (lower.contains('kommersant.ru')) return 'kommersant';
    if (lower.contains('vedomosti.ru')) return 'vedomosti';

    // ---- ЧАСЫ ----
    if (lower.contains('danielwellington.com')) return 'danielwellington';
    if (lower.contains('fossil.com')) return 'fossil';
    if (lower.contains('seikowatches.com')) return 'seiko';
    if (lower.contains('citizenwatch.com')) return 'citizen';
    if (lower.contains('omega.com')) return 'omega';
    if (lower.contains('rolex.com')) return 'rolex';
    if (lower.contains('tagheuer.com')) return 'tagheuer';

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
      case 'distrokid': return 'DistroKid';
      case 'tunecore': return 'TuneCore';
      case 'cdbaby': return 'CD Baby';
      case 'amuse': return 'Amuse';
      case 'bandlab': return 'BandLab';
      case 'soundtrap': return 'Soundtrap';
      case 'landr': return 'LANDR';
      case 'mastering': return 'Mastering';

      // ---- ВИДЕО ----
      case 'youtube': return 'YouTube';
      case 'vimeo': return 'Vimeo';
      case 'twitch': return 'Twitch';
      case 'bilibili': return 'Bilibili';
      case 'dailymotion': return 'Dailymotion';
      case 'likee': return 'Likee';
      case 'kwai': return 'Kwai';
      case 'mojo': return 'Mojo';
      case 'kick': return 'Kick';
      case 'rumble': return 'Rumble';
      case 'odysee': return 'Odysee';
      case 'clapper': return 'Clapper';
      case 'triller': return 'Triller';
      case 'firework': return 'Firework';
      case 'clipchamp': return 'Clipchamp';

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
      case 'threads': return 'Threads';
      case 'bluesky': return 'Bluesky';
      case 'mastodon': return 'Mastodon';
      case 'clubhouse': return 'Clubhouse';
      case 'ok': return 'Одноклассники';
      case 'dzen': return 'Яндекс Дзен';
      case 'habr': return 'Habr';
      case 'vc': return 'VC.ru';
      case 'pikabu': return 'Pikabu';
      case 'bereal': return 'BeReal';
      case 'weverse': return 'Weverse';
      case 'sarafan': return 'Сарафан';
      case 'livejournal': return 'LiveJournal';

      // ---- ПЛАТФОРМЫ ДЛЯ ТВОРЦОВ ----
      case 'patreon': return 'Patreon';
      case 'boosty': return 'Boosty';
      case 'donationalerts': return 'DonationAlerts';
      case 'buymeacoffee': return 'Buy Me a Coffee';
      case 'kofi': return 'Ko-fi';
      case 'gumroad': return 'Gumroad';
      case 'stan': return 'Stan Store';
      case 'whop': return 'Whop';

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
      case 'megamarket': return 'Мегамаркет';
      case 'yandex_market': return 'Яндекс Маркет';
      case 'goods': return 'Goods';
      case 'sbermarket': return 'СберМаркет';

      // ---- ПЛАТФОРМЫ ДЛЯ МЕРЧА ----
      case 'redbubble': return 'Redbubble';
      case 'society6': return 'Society6';
      case 'teepublic': return 'TeePublic';
      case 'printful': return 'Printful';
      case 'printify': return 'Printify';
      case 'amazon_merch': return 'Amazon Merch';

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
      case 'levi': return 'Levi\'s';
      case 'converse': return 'Converse';
      case 'vans': return 'Vans';
      case 'timberland': return 'Timberland';
      case 'drmartens': return 'Dr. Martens';
      case 'skechers': return 'Skechers';
      case 'crocs': return 'Crocs';
      case 'massimodutti': return 'Massimo Dutti';
      case 'oysho': return 'Oysho';
      case 'moncler': return 'Moncler';
      case 'victoriassecret': return 'Victoria\'s Secret';

      // ---- ПРЕМИУМ БРЕНДЫ ----
      case 'chanel': return 'Chanel';
      case 'dior': return 'Dior';
      case 'gucci': return 'Gucci';
      case 'prada': return 'Prada';
      case 'versace': return 'Versace';
      case 'armani': return 'Giorgio Armani';
      case 'burberry': return 'Burberry';
      case 'fendi': return 'Fendi';
      case 'loewe': return 'Loewe';
      case 'bottega': return 'Bottega Veneta';
      case 'balenciaga': return 'Balenciaga';
      case 'saintlaurent': return 'Saint Laurent';
      case 'givenchy': return 'Givenchy';
      case 'valentino': return 'Valentino';
      case 'miumiu': return 'Miu Miu';
      case 'celine': return 'Celine';
      case 'hermes': return 'Hermès';
      case 'louisvuitton': return 'Louis Vuitton';

      // ---- ОБУВЬ ----
      case 'louboutin': return 'Christian Louboutin';
      case 'manoloblahnik': return 'Manolo Blahnik';
      case 'jimmychoo': return 'Jimmy Choo';
      case 'gianvitorossi': return 'Gianvito Rossi';
      case 'aquazzura': return 'Aquazzura';
      case 'rogervivier': return 'Roger Vivier';
      case 'sergiorossi': return 'Sergio Rossi';
      case 'giuseppezanotti': return 'Giuseppe Zanotti';

      // ---- СУМКИ И АКСЕССУАРЫ ----
      case 'mulberry': return 'Mulberry';
      case 'strathberry': return 'Strathberry';
      case 'polene': return 'Polène Paris';
      case 'mansurgavriel': return 'Mansur Gavriel';
      case 'demellier': return 'DeMellier';
      case 'cuyana': return 'Cuyana';
      case 'everlane': return 'Everlane';

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
      case 'esteelauder': return 'Estée Lauder';
      case 'clinique': return 'Clinique';
      case 'lancome': return 'Lancôme';
      case 'lamer': return 'La Mer';
      case 'bobbibrown': return 'Bobbi Brown';
      case 'shuuemura': return 'Shu Uemura';
      case 'makeupforever': return 'Make Up For Ever';
      case 'urbandecay': return 'Urban Decay';
      case 'toofaced': return 'Too Faced';
      case 'tarte': return 'Tarte';
      case 'nars': return 'NARS';
      case 'benefit': return 'Benefit Cosmetics';
      case 'innisfree': return 'Innisfree';
      case 'etudehouse': return 'Etude House';
      case 'cosrx': return 'COSRX';
      case 'sokoglam': return 'Soko Glam';
      case 'yesstyle': return 'YesStyle';
      case 'letual': return 'Л\'Этуаль';
      case 'rivgosh': return 'Рив Гош';
      case 'goldapple': return 'Золотое Яблоко';

      // ---- УКРАШЕНИЯ ----
      case 'pandora': return 'Pandora';
      case 'swarovski': return 'Swarovski';
      case 'tiffany': return 'Tiffany & Co.';
      case 'cartier': return 'Cartier';
      case 'sunlight': return 'Sunlight';
      case 'zolotoy585': return '585 Золотой';
      case 'yashma': return 'Яшма Золото';
      case 'chopard': return 'Chopard';
      case 'bulgari': return 'Bvlgari';
      case 'vancleef': return 'Van Cleef & Arpels';
      case 'adamas': return 'Адамас';
      case 'sokolov': return 'Соколов';

      // ---- ССЫЛКИ ДЛЯ ТВОРЦОВ ----
      case 'linktree': return 'Linktree';
      case 'beacons': return 'Beacons';
      case 'carrd': return 'Carrd';
      case 'milkshake': return 'Milkshake';
      case 'snipfeed': return 'Snipfeed';

      // ---- ЕДА ----
      case 'yandex_lavka': return 'Яндекс Лавка';
      case 'sbermarket': return 'СберМаркет';
      case 'ozon_fresh': return 'Ozon Fresh';
      case 'vkusvill': return 'ВкусВилл';
      case 'dodopizza': return 'Додо Пицца';
      case 'sushiwok': return 'Суши Wok';
      case 'tanuki': return 'Тануки';
      case 'yakitoriya': return 'Якитория';
      case 'eda': return 'Eda.ru';

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
      case 'strava': return 'Strava';
      case 'myfitnesspal': return 'MyFitnessPal';

      // ---- ДЕТСКИЕ ТОВАРЫ ----
      case 'pocemu4ek': return 'Почемучек';
      case 'korablik': return 'Кораблик';
      case 'mothercare': return 'Mothercare';
      case 'hamleys': return 'Hamleys';
      case 'mirkubikov': return 'Мир кубиков';
      case 'babyru': return 'Baby.ru';
      case 'mamaclub': return 'Mama Club';
      case 'whattoexpect': return 'What to Expect';
      case 'parents': return 'Parents';
      case 'mishka': return 'Мишка Онлайн';

      // ---- ЗООТОВАРЫ ----
      case 'zoomagazin': return 'Зоомагазин';
      case 'betkhoven': return 'Бетховен';
      case 'lapy4': return 'Четыре Лапы';
      case 'chewy': return 'Chewy';
      case 'petco': return 'Petco';
      case 'petsmart': return 'Petsmart';
      case 'petmd': return 'PetMD';

      // ---- ТВОРЧЕСТВО ----
      case 'leonardo': return 'Леонардо';
      case 'peredvizhnik': return 'Передвижник';
      case 'artfox': return 'ArtFox';
      case 'craftsy': return 'Craftsy';
      case 'lovecrafts': return 'LoveCrafts';

      // ---- ЖЕНСКИЕ СЕРВИСЫ ----
      case 'cosmopolitan': return 'Cosmopolitan';
      case 'elle': return 'Elle';
      case 'vogue': return 'Vogue';
      case 'harpersbazaar': return 'Harper\'s Bazaar';
      case 'grazia': return 'Grazia';
      case 'glamour': return 'Glamour';
      case 'marieclaire': return 'Marie Claire';
      case 'instyle': return 'InStyle';
      case 'weddingru': return 'Wedding.ru';
      case 'theknot': return 'The Knot';
      case 'brides': return 'Brides';
      case 'lavanda': return 'Lavanda Media';
      case 'psychologies': return 'Psychologies';
      case 'mel': return 'Mel.fm';
      case 'woman': return 'Woman.ru';
      case 'mamlife': return 'Mamlife';
      case '7ya': return '7ya.ru';
      case 'umama': return 'U-Mama';
      case 'babyblog': return 'BabyBlog';
      case 'livemaster': return 'Livemaster';

      // ---- ОБРАЗОВАНИЕ ----
      case 'foxford': return 'Фоксфорд';
      case 'uchi': return 'Учи.ру';
      case 'getcourse': return 'GetCourse';
      case 'teachable': return 'Teachable';
      case 'thinkific': return 'Thinkific';

      // ---- НЕЙРОСЕТИ ----
      case 'openai': return 'OpenAI';
      case 'midjourney': return 'Midjourney';
      case 'stability': return 'Stability AI';
      case 'runway': return 'Runway';
      case 'pika': return 'Pika';
      case 'leonardo_ai': return 'Leonardo.ai';
      case 'perplexity': return 'Perplexity';
      case 'claude': return 'Claude';
      case 'deepseek': return 'DeepSeek';
      case 'character': return 'Character.ai';
      case 'replika': return 'Replika';

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
      case 'adobe': return 'Adobe';
      case 'adobe_cc': return 'Adobe Creative Cloud';

      // ---- ИГРЫ ----
      case 'steam': return 'Steam';
      case 'epic': return 'Epic Games';
      case 'gog': return 'GOG';
      case 'itch': return 'itch.io';
      case 'playstation': return 'PlayStation';
      case 'xbox': return 'Xbox';
      case 'nintendo': return 'Nintendo';
      case 'battlenet': return 'Battle.net';
      case 'ubisoft': return 'Ubisoft';
      case 'ea': return 'EA';
      case 'rockstar': return 'Rockstar';
      case 'riot': return 'Riot Games';
      case 'cybersport': return 'Киберспорт.ру';
      case 'faceit': return 'FACEIT';
      case 'ggscore': return 'GGScore';

      // ---- КРИПТО ----
      case 'opensea': return 'OpenSea';
      case 'rarible': return 'Rarible';
      case 'foundation': return 'Foundation';
      case 'superrare': return 'SuperRare';
      case 'binance': return 'Binance';
      case 'bybit': return 'Bybit';
      case 'okx': return 'OKX';
      case 'coinmarketcap': return 'CoinMarketCap';
      case 'coingecko': return 'CoinGecko';

      // ---- КНИГИ ----
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
      case '500px': return '500px';
      case 'flickr': return 'Flickr';
      case 'vsco': return 'VSCO';
      case 'imgur': return 'Imgur';
      case 'giphy': return 'GIPHY';

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

      // ---- БРОНИРОВАНИЕ ----
      case 'booking': return 'Booking.com';
      case 'agoda': return 'Agoda';
      case 'airbnb': return 'Airbnb';
      case 'tripadvisor': return 'Tripadvisor';
      case 'skyscanner': return 'Skyscanner';
      case 'kiwi': return 'Kiwi.com';
      case 'expedia': return 'Expedia';
      case 'kayak': return 'Kayak';
      case 'hostelworld': return 'Hostelworld';
      case 'aviasales': return 'Aviasales';
      case 'tutu': return 'Туту.ру';
      case 'blablacar': return 'BlaBlaCar';
      case 'trivago': return 'Trivago';
      case 'onetwotrip': return 'OneTwoTrip';
      case 'timepad': return 'Timepad';
      case 'eventbrite': return 'Eventbrite';

      // ---- ЗДОРОВЬЕ ----
      case 'webmd': return 'WebMD';
      case 'mayoclinic': return 'Mayo Clinic';
      case 'nhs': return 'NHS';
      case 'apteka': return 'Аптека.ру';
      case 'zdravcity': return 'ЗдравСити';
      case 'iherb': return 'iHerb';
      case 'docdoc': return 'DocDoc';
      case 'yandex_health': return 'Яндекс Здоровье';

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
      case 'foodpanda': return 'Foodpanda';
      case 'talabat': return 'Talabat';
      case 'zomato': return 'Zomato';
      case 'swiggy': return 'Swiggy';

      // ---- ТАКСИ ----
      case 'uber': return 'Uber';
      case 'lyft': return 'Lyft';
      case 'gett': return 'Gett';
      case 'getaround': return 'Getaround';
      case 'sharenow': return 'Share Now';
      case 'citymobil': return 'Ситимобил';

      // ---- РАБОТА ----
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
      case 'upwork': return 'Upwork';
      case 'freelancer': return 'Freelancer';
      case 'fiverr': return 'Fiverr';
      case 'toptal': return 'Toptal';
      case 'glassdoor': return 'Glassdoor';
      case 'indeed': return 'Indeed';
      case 'monster': return 'Monster';

      // ---- АВТО ----
      case 'avtocod': return 'Автокод';
      case 'drom': return 'Drom.ru';
      case 'auto': return 'Auto.ru';
      case 'avtorun': return 'Авторун';
      case 'drive2': return 'Drive2.ru';
      case 'avtopro': return 'AvtoPro';
      case 'exist': return 'Exist';
      case 'emex': return 'Emex';

      // ---- ТЕХНИКА ----
      case 'samsung': return 'Samsung';
      case 'xiaomi': return 'Xiaomi';
      case 'huawei': return 'Huawei';
      case 'sony': return 'Sony';
      case 'lg': return 'LG';
      case 'philips': return 'Philips';
      case 'canon': return 'Canon';
      case 'nikon': return 'Nikon';
      case 'gopro': return 'GoPro';
      case 'dji': return 'DJI';

      // ---- ЯНДЕКС-СЕРВИСЫ ----
      case 'yandex_eda': return 'Яндекс Еда';
      case 'yandex_taxi': return 'Яндекс Такси';
      case 'yandex_drive': return 'Яндекс Драйв';

      // ---- ЗНАКОМСТВА ----
      case 'tinder': return 'Tinder';
      case 'bumble': return 'Bumble';
      case 'mamba': return 'Mamba';
      case 'teamo': return 'Teamo';
      case 'dating': return 'Dating.ru';

      // ---- ПОДКАСТЫ ----
      case 'podcastru': return 'Podcast.ru';
      case 'podster': return 'Podster.fm';
      case 'podfm': return 'Podfm';
      case 'glow': return 'Glow';
      case 'transistor': return 'Transistor';

      // ---- НОВОСТИ ----
      case 'bbc': return 'BBC';
      case 'cnn': return 'CNN';
      case 'nytimes': return 'The New York Times';
      case 'wsj': return 'The Wall Street Journal';
      case 'forbes': return 'Forbes';
      case 'bloomberg': return 'Bloomberg';
      case 'ft': return 'Financial Times';
      case 'economist': return 'The Economist';
      case 'wired': return 'Wired';
      case 'techcrunch': return 'TechCrunch';
      case 'theverge': return 'The Verge';
      case 'cnet': return 'CNET';
      case 'gizmodo': return 'Gizmodo';
      case 'mashable': return 'Mashable';
      case 'buzzfeed': return 'BuzzFeed';
      case 'huffpost': return 'HuffPost';
      case 'vox': return 'Vox';
      case 'politico': return 'Politico';
      case 'axios': return 'Axios';
      case 'businessinsider': return 'Business Insider';
      case 'fastcompany': return 'Fast Company';
      case 'inc': return 'Inc.';
      case 'entrepreneur': return 'Entrepreneur';
      case 'hbr': return 'Harvard Business Review';
      case 'natgeo': return 'National Geographic';
      case 'nature': return 'Nature';
      case 'sciencemag': return 'Science';
      case 'pnas': return 'PNAS';
      case 'sciencedaily': return 'ScienceDaily';
      case 'livescience': return 'LiveScience';
      case 'phys': return 'Phys.org';
      case 'popularmechanics': return 'Popular Mechanics';
      case 'engadget': return 'Engadget';
      case 'arstechnica': return 'Ars Technica';
      case 'zdnet': return 'ZDNet';
      case 'rt': return 'RT';
      case 'tass': return 'ТАСС';
      case 'ria': return 'РИА Новости';
      case 'lenta': return 'Lenta.ru';
      case 'gazeta': return 'Газета.ру';
      case 'kommersant': return 'Коммерсантъ';
      case 'vedomosti': return 'Ведомости';

      // ---- ЧАСЫ ----
      case 'danielwellington': return 'Daniel Wellington';
      case 'fossil': return 'Fossil';
      case 'seiko': return 'Seiko';
      case 'citizen': return 'Citizen';
      case 'omega': return 'Omega';
      case 'rolex': return 'Rolex';
      case 'tagheuer': return 'TAG Heuer';

      default:
        try {
          return Uri.parse(url).host.replaceAll('www.', '');
        } catch (_) {
          return 'Link';
        }
    }
  }
}