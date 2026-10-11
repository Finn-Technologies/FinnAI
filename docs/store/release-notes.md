# FinnAI — Google Play release notes

Google Play's *"What's new in this version"* field allows **500 characters per
language**. The strings below stay inside that limit and say the same things in
the five languages the store listing ships (`en-US`, `it-IT`, `es-ES`, `fr-FR`,
`de-DE`). Paste each block into the matching Play Console language, one release
at a time; older releases are kept below it.

## 2.0.0-beta (build 11) — 2026-10-07

Baseline for *new vs old*: **build 10**, the previous upload. Checked against
git: build 10 already shipped hands-free voice and FinnAI Code, so they are not
listed as new; what landed after it is the two model tiers, Code's Linux
sandbox, the speed and memory work, the visual refresh, accessibility and the
desktop build.

### What's new — en-US

```
FinnAI 2.0 beta — a big update.
• A bigger brain on capable phones: FinnAI picks the 3B or 1.6B model, all on-device.
• FinnAI Code runs a real Linux sandbox on your phone: create, edit, run and install projects.
• Up to 2x faster first replies, and less memory when you are not sending images.
• A fresh look: vivid colour, true-black dark mode, filled icons.
• Better accessibility, plus a new Linux desktop build.
```

### What's new — it-IT

```
FinnAI 2.0 beta — un grande aggiornamento.
• Più potenza sui telefoni compatibili: FinnAI sceglie il modello 3B o 1.6B, sempre in locale.
• FinnAI Code esegue un vero sandbox Linux sul telefono: crea, modifica, esegue e installa progetti.
• Risposte fino a 2 volte più rapide e meno memoria quando non invii immagini.
• Nuovo look: colori vivaci, tema scuro nero puro, icone piene.
• Accessibilità migliorata e nuova versione per Linux desktop.
```

### What's new — es-ES

```
FinnAI 2.0 beta: una gran actualización.
• Más potencia en móviles compatibles: FinnAI elige el modelo 3B o 1.6B, siempre en local.
• FinnAI Code ejecuta un Linux real en tu móvil: crea, edita, ejecuta e instala proyectos.
• Respuestas hasta 2 veces más rápidas y menos memoria si no envías imágenes.
• Nuevo aspecto: colores vivos, modo oscuro negro puro, iconos rellenos.
• Mejor accesibilidad y nueva versión para Linux de escritorio.
```

### What's new — fr-FR

```
FinnAI 2.0 bêta — une grande mise à jour.
• Plus de puissance sur les téléphones compatibles : FinnAI choisit le modèle 3B ou 1.6B.
• FinnAI Code exécute un vrai Linux sur votre téléphone : créez, modifiez, exécutez et installez des projets.
• Réponses jusqu'à 2x plus rapides et moins de mémoire sans envoi d'image.
• Nouveau look : couleurs vives, noir pur, icônes pleines.
• Meilleure accessibilité et version Linux pour ordinateur.
```

### What's new — de-DE

```
FinnAI 2.0 Beta — ein großes Update.
• Mehr Leistung auf geeigneten Telefonen: FinnAI wählt das 3B- oder 1.6B-Modell, weiterhin komplett lokal.
• FinnAI Code führt eine echte Linux-Sandbox auf dem Telefon aus: Projekte erstellen, bearbeiten, ausführen und installieren.
• Bis zu 2x schnellere erste Antworten und weniger Speicher ohne Bildversand.
• Neuer Look: kräftige Farben, echtes Schwarz, gefüllte Icons.
• Bessere Barrierefreiheit und eine Linux-Desktop-Version.
```

## New vs old — build 11 against build 10

| Area | Build 10 (2026-10-04) | Build 11 |
|---|---|---|
| **Model** | One on-device model | Two tiers, chosen per device: LFM2.5-VL **3B** on capable phones, **1.6B** elsewhere (ADR 0013) |
| **FinnAI Code** | Coding agent with a basic terminal; cloud keys only | A real Alpine Linux on Android (proot + network; ADR 0012): create, edit, run, install; `@file` mentions, slash commands, approval prompts with *Allow in session*, before/after on file actions, changes review, retry on transient failures, and a new on-device (Finn) option beside the cloud keys |
| **Speed** | — | New-chat first reply on the 3B phone **3.78 s → 1.61 s**; Tab A8 first word **6.3 s → ~1.7 s**; a topic change keeps the session instead of re-reading the chat |
| **Memory** | Vision projector held for every text chat (~850 MB) | Projector loads on demand, when an image is attached |
| **Look** | Outline icons, previous palette | Vivid colour, true-black dark mode, filled (Hugeicons) icons, brand-gradient greeting and send button |
| **Accessibility** | — | TalkBack fixes, 48 dp touch targets, no idle animations or backdrop blur |
| **Platforms** | Android, OpenHarmony | Android, OpenHarmony, and a new **desktop Linux** build |
| **Copy** | — | The date no longer leaks into answers unless you ask about it |
| **Voice** | Hands-free, with spoken replies | Unchanged from build 10 |

## Notes for the reviewer

- Everything is on-device; the only network use is the one-time model download
  and the explicit, per-query web grounding — unchanged by this release.
- The app is localised into the same five languages as these strings.
- If the previous Play upload predates build 10 (the store listing text does not
  mention voice, Code or image understanding), promote those to headline items —
  they are new to public users even though they are not new since build 10.
