# VOICE TESTS

**Status: automated tests only. Nothing below has been run on a real phone yet.** Run the matrix on a device and fill the last
columns. All Darija and Arabic wording is a draft (`reviewed:false`) until a native speaker signs `docs/darija_review.csv`.

## Automated (pass)
`test/voice_test.dart`: normalisation of Arabic variants and Arabizi, fuzzy matching, 16 utterances across Darija / Arabic / English /
French for the intents, confidence below 0.6 never guessed, phrase order for the advice and rotation sentences in all four languages,
every phrase id the builder can produce exists in `phrases.json`, all Darija and Arabic flagged as draft.

## Matrix to run on a device (language × intent × connectivity × audio source)
Utterances (draft, to be native-reviewed):
| intent | Darija | Arabic | French | English |
|---|---|---|---|---|
| what to plant | شنو نزرع | ماذا أزرع | quelle culture | which crop |
| water | شحال ديال الما | كم من الماء | combien d'eau | how much water |
| less rain | شنو إلا قلت الشتا | ماذا لو قل المطر | et s'il pleut moins | what if there is less rain |
| rotation | شنو أحسن تناوب | ما أفضل تناوب | quelle rotation | which rotation |
| explain | شرح ليا النتيجة | اشرح النتيجة | explique ce résultat | explain this result |
| repeat / language / help | عاود · بدل اللغة · عاوني | أعد · غيّر اللغة · ساعدني | répète · changer de langue · aide | repeat · change language · help |

| language | intent | online | offline | bundled clips | live backend | text fallback shown | result / notes |
|---|---|---|---|---|---|---|---|
| Darija | what to plant | ☐ | ☐ | ☐ | ☐ | ☐ | |
| Darija | water | ☐ | ☐ | ☐ | ☐ | ☐ | |
| Darija | less rain (simulation) | ☐ | ☐ | ☐ | ☐ | ☐ | |
| Darija | rotation | ☐ | ☐ | ☐ | ☐ | ☐ | |
| Darija | explain | ☐ | ☐ | ☐ | ☐ | ☐ | |
| Arabic | what to plant | ☐ | ☐ | ☐ | ☐ | ☐ | |
| Arabic | water | ☐ | ☐ | ☐ | ☐ | ☐ | |
| Arabic | less rain (simulation) | ☐ | ☐ | ☐ | ☐ | ☐ | |
| Arabic | rotation | ☐ | ☐ | ☐ | ☐ | ☐ | |
| Arabic | explain | ☐ | ☐ | ☐ | ☐ | ☐ | |
| French | what to plant | ☐ | ☐ | ☐ | ☐ | ☐ | |
| French | water | ☐ | ☐ | ☐ | ☐ | ☐ | |
| French | less rain (simulation) | ☐ | ☐ | ☐ | ☐ | ☐ | |
| French | rotation | ☐ | ☐ | ☐ | ☐ | ☐ | |
| French | explain | ☐ | ☐ | ☐ | ☐ | ☐ | |
| English | what to plant | ☐ | ☐ | ☐ | ☐ | ☐ | |
| English | water | ☐ | ☐ | ☐ | ☐ | ☐ | |
| English | less rain (simulation) | ☐ | ☐ | ☐ | ☐ | ☐ | |
| English | rotation | ☐ | ☐ | ☐ | ☐ | ☐ | |
| English | explain | ☐ | ☐ | ☐ | ☐ | ☐ | |

Also check: microphone permission asked only at first use with the reason first · denied → buttons only · low confidence → "I did not
understand" + buttons · "what if there is less rain" opens the Shock Lab, the banner says "What-if scenario", and the spoken sentence
gives the chance of three good seasons · volume and speed sliders · speech stops when the screen changes · never autoplays on launch.

## Known limits
`speech_to_text` is fixed to the chosen language (`ar_MA` for Darija, `ar_SA` for Arabic, `fr_FR`, `en_US`). Android's Moroccan Arabic
recognition quality is unknown until tested. Auto-detect of the spoken language is not implemented. No system TTS package is in the
stack: without bundled clips (or your own endpoint) the app shows the sentence as text.
