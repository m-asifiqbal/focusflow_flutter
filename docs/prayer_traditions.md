# Prayer in each tradition's own words

The Prayer module started from Islam, so its base vocabulary (Salah, Nafl, Dhikr, Suhoor, Iftar, Jamaat, Asr …) was
Islamic for everybody. Every tradition now has its own **profile** (words, kinds, time anchors, fast and congregation
wording, places, counts), its own **catalogue** of practices and, optionally, a **school** (Hanafi, Catholic, Reform,
Smarta, Zen …) that picks better defaults. A person who keeps several traditions sees each practice in its own words:
everything reads `practice.tradition`, never the user's one "main" tradition.

| Where | What |
|---|---|
| `domain/services/tradition_profile.dart` | `PrayerTraditionProfile.of(tradition)`: kinds offered and their names, sun anchors and their names, offsets, fast words (`FastWords`), congregation words, places, goals, mark / log wording, editor titles and hints. |
| `domain/entities/prayer_school.dart` | `PrayerSchool` (25 schools in 5 traditions) and the school question per tradition. Stored per tradition in `PrayerPrefs.schools` (settings JSON, no schema change). A Muslim's choice also sets the Asr time (Hanafi shadow or standard). |
| `domain/services/prayer_presets.dart` + `presets/*.dart` | `PrayerPresets.of(tradition, now, school:)`. A preset has `core`, `schools` (only for), `coreFor` (ticked for), `notFor`, `variant`, and a `hint` ("2 rak'at · fard"). School skipped → the common set ticked, each school's own practices offered as options. |
| `SolarEvent` | three new halachic hours: `sofZmanShema`, `sofZmanTefillah`, `plagHamincha` (quarter, third and 10¾/12 of the day). Everything else (muhurta, tzeit, candle lighting, canonical hours) is an existing sun event ± minutes. |
| editor | kind chips of the tradition, its names for the sun events ("Sunrise (netz)", "Latest morning prayer (sof zman Tefillah)", "Sunrise (pratah)"), tradition offsets (−96 for Brahma muhurta, 42/50/72 for tzeit), a **Length** row (a 20-minute sit moves the end, keeps the start), the tradition's congregation section (minyan, satsang, sangha, service; the offline "Auto" estimate stays Islam-only), places, counter goals, hints. |
| notifications, rows, hero, log sheet | Iftar only for Islam ("The fast ends", "Time to break the fast", "The observance ends"); "Mark prayed / done / practised / studied / kept"; "Minyan 1:15 PM", "Satsang …". |

A test (`test/features/prayers/domain/prayer_traditions_test.dart`) fails if an Islamic word appears in another
tradition's profile.

## What the research found (summary)

* **Islam** — five prayers; Witr is wajib for Hanafis (sunnah for the others); Asr start differs by school (the app's
  Hanafi toggle); Jafari: Maghrib starts when the redness fades (~15 min after sunset), no congregational Taraweeh,
  Dhuhr/Asr and Maghrib/Isha may be combined. Duha: ~20 min after sunrise to ~10 min before noon. Tahajjud: last third of the
  night to dawn. Adhkar "100" is one dhikr, not the whole set. Qada is a counter, not a status. Never use adhan or Quran audio as an alert.
* **Christianity** — branches differ more than anything else: Catholic Liturgy of the Hours (no clock times in the
  GILH), Angelus 6/12/18, Rosary 5 decades, Divine Mercy at 3 pm, Friday penance; Orthodox prayer rule, Jesus Prayer on the
  prayer rope (33), the Hours, Divine Liturgy, Wednesday and Friday fast; Coptic Agpeya (seven hours, 41 "Lord, have mercy");
  Anglican Daily Office and 33 beads; Protestant quiet time. "Fasting" and "abstinence" are different things.
* **Judaism** — zmanim (GRA hours: Shema by a quarter of the day, Tefillah by a third; mincha gedola = chatzot + 30;
  plag = 10¾ of 12 hours; tzeit = 8.5° or 42/50/72 min; candle lighting 18 min, Jerusalem 40; Havdalah at tzeit). Minyan is a
  quorum of ten — never write "ten men" (Conservative and Reform count women). Reform keeps daily services optional.
* **Hinduism** — plural. Home puja, a 108 mala, evening lamp and aarti are near-universal; the three sandhyas and
  Gayatri are family-tradition practices (Smarta, Sri Vaishnava, Arya Samaj); ISKCON: 16 rounds. Brahma muhurta = 96 to 48
  min before sunrise; Pratah/Sayam sandhya around sunrise/sunset; Abhijit around midday. Weekday–deity vratas are regional.
* **Buddhism** — "practice", "sitting", "chanting", never "prayer" as the umbrella; duration-first sits; Pure Land
  nembutsu is gratitude, not counted; Tibetan mala rounds of 108; Nichiren gongyo and daimoku; the group is the *sangha*;
  streaks sit badly with non-attachment (the module keeps the same gentle progress for everyone).

Where sources disagreed the preset takes the commonest default and the user can change it (Isha end, Maghrib offset for Jafari,
Pradosh, Brahma muhurta start). The Islamic report suggested a "legal midnight" (sunset→Fajr); the standard
(sunset→sunrise) used by praytimes.org's default and the app is kept, because that is what the Sunni methods use.

## Sensitivities the module follows

No rulings or "you must"; times are informational ("follow your local luach / mosque / panchang"). No images of
sacred figures; deity names only as text; no generated devotional imagery; Om, lotus and the dharmachakra only as small
neutral glyphs. No gamification of merit, prayer or fasting; missed days are not shamed. Do not assume gender, caste, diet
or age (Sandhyavandanam is worded "if your family tradition keeps it"; fast ages are not asked). Do not reproduce liturgical
or sacred text, only names and references. Hebrew/Sanskrit names keep the language's customary transliteration.

## Calendar rules (round 2)

A practice repeats by weekday, or by a **calendar rule** (`Prayer.calendar`, stored as text in `prayers.calendar_rule`, added with
no schema bump; a `|-1` / `|1` suffix is the person's one-day nudge). Engines in `domain/services/calendars/`, matching in
`calendar_rules.dart`, the editor's "Repeats on" row in `prayer_calendar_section.dart`. A rule replaces the weekdays; the date range
still applies. Keys: `hspan:M-D1-D2` (Hijri), `hdays:13,14,15`, `hfast:id`, `hebrew:roshchodesh|omer|chanukah`,
`season:lent|holyweek|advent|eastertide|greatlent`, `fixed:M-D..M-D`, `tithi:11,26[@hour]`, `moon:0,1,2,3`.

* **Hijri** — the tabular calendar plus the saved ±2 day correction (Settings › Prayer › Hijri date): Ramadan (fast and Taraweeh,
  no stale date range), white days, Arafah, Ashura, six of Shawwal, both Eid prayers. Not done: Laylat al-Qadr nights.
* **Hebrew** — exact arithmetic (Dershowitz–Reingold): the six fasts with their Shabbat shifts (Tzom Gedaliah, 17 Tammuz and Tisha B'Av to
  Sunday, Esther to Thursday), Omer (nights 1–49), Rosh Chodesh, Chanukah, the Hebrew date on the Prayer page (rolls at sunset). Shabbat /
  Yom Tov quiet mode (Settings › Prayer › Shabbat and Yom Tov, Judaism only, default off): no Prayer notification from 18 minutes before sunset
  on the eve to 42 minutes after sunset; Israel (one day) or elsewhere (two). Not done: the other festivals as rules, Torah portions.
* **Easter-based** — Meeus/Jones/Butcher Easter, Pascha (Julian +13): Lent (Ash Wednesday to Holy Saturday, Sundays excluded), Holy
  Week, Advent, Eastertide, the Orthodox Great Lent; Nativity and Dormition fasts on Revised Julian dates (old-calendar churches differ;
  the Apostles' fast is not offered). The Prayer page shows "Lent · week 3".
* **Lunar** — tithi from the Moon–Sun elongation (Meeus ch. 47 terms, ≈ 0.1°): Ekadashi (sunrise rule), Pradosh (at 18:00), Sankashti
  (at 20:00), Purnima, Amavasya; Uposatha / Poya moon days. Smarta and Vaishnava Ekadashi, Nepali, Thai and Sri Lankan almanacs can differ by
  a day — every moon-based rule is labelled "approximate — confirm locally" with a one-day nudge. Not done: Vesak, Asalha, Vassa, Tibetan days.

## Sources

Islam — praytimes.org (methods, calculation); islamqa.org (Hanafi on Witr and sunnah); islamweb.net; moonsighting.com.
Christianity — universalis.com (Hours); vatican.va (canons on fasting); oca.org (Orthodox fasting seasons); Wikipedia: Date of Easter,
Revised Julian calendar, Canonical hours, Agpeya. Judaism — hebcal.com (zmanim, candle lighting, fast days); chabad.org (zmanim);
jta.org (minyan); myjewishlearning.com. Hinduism — drikpanchang.com (muhurta, Ekadashi, Pradosh); iskcondesiretree.com (Ekadashi rules);
hinduamerican.org (puja at home; images); himalayanacademy.com. Buddhism — accesstoinsight.org (Uposatha, Eight Precepts);
abhayagiri.org; sfzc.org; lionsroar.com; buddhanet.net; tricycle.org.
Reports were produced by research agents and are not verified by clergy or scholars — each community should review its own
words and defaults before a public release (as with the translations, see localization.md).
