Задача: глубокий UI redesign Omnia под предоставленный дизайн-концепт.

ВАЖНО:
Ты не можешь видеть изображение-референс, поэтому ниже приведена его точная текстовая спецификация.
Не пытайся интерпретировать задачу как косметический UI Polish.
Нужно привести существующий SwiftUI-интерфейс Omnia к единой дизайн-системе, максимально близкой к описанному ниже концепту.

UX уже завершён и frozen.
НЕ менять:
- Domain
- Application/business logic
- Infrastructure
- Frozen UX contracts
- OmniRoute integration behavior
- Provider API contracts
- navigation model
- conversation behavior
- message streaming behavior

Можно менять presentation/UI слой, SwiftUI layout, styling, reusable UI components, spacing, typography, backgrounds, cards, shadows, icons и visual hierarchy.

Главная цель:
Omnia должен визуально восприниматься как современный premium AI client уровня Gemini/ChatGPT, но со своей фирменной эстетикой:
dark futuristic + minimal + premium + clean + private/local AI.

==================================================
1. ОБЩАЯ ВИЗУАЛЬНАЯ КОНЦЕПЦИЯ
==================================================

Основной стиль:

- глубокий почти чёрный фон;
- холодный navy/blue undertone;
- subtle gradients;
- purple/indigo как основной accent;
- cyan как secondary accent;
- green только для success/active state;
- очень мягкие shadows;
- большие rounded corners;
- много воздуха;
- минимальное количество визуального шума;
- никаких тяжёлых рамок;
- никакого старого "enterprise settings UI";
- интерфейс должен выглядеть как современное native iOS AI-приложение.

Визуальное ощущение:

"premium private AI assistant"

Не делать:
- насыщенный neon cyberpunk;
- чрезмерные glow-эффекты;
- слишком много градиентов;
- огромные кнопки;
- тяжёлые borders;
- плотную компоновку;
- Windows/desktop-style controls;
- generic Form/List appearance SwiftUI.

==================================================
2. ЦВЕТОВАЯ СИСТЕМА
==================================================

Dark background:

Primary background:
#050911 приблизительно

Secondary/elevated surface:
#0A0F19

Card/elevated surface:
#0D1420

Subtle border:
#202A3A

Primary text:
#F0F2F7

Secondary text:
#8D96A8

Muted text:
#626B7C

Primary accent:
#8A2BE2 / vivid purple

Accent purple:
#7C3AED

Secondary cyan:
#00D4FF

Success:
#22C55E

Warning:
#F59E0B

Error:
#EF4444

Важно:
Цвета должны быть оформлены через semantic design tokens,
а не разбросаны по View через hardcoded Color(...).

Например:

DesignTokens:
- background
- surface
- elevatedSurface
- border
- textPrimary
- textSecondary
- textMuted
- accent
- accentSecondary
- success
- warning
- error

Если в проекте уже существует Dynamic Type / semantic token infrastructure —
использовать её и расширить, а не создавать вторую систему.

==================================================
3. TYPOGRAPHY
==================================================

Ориентир — native Apple typography / SF Pro.

Иерархия:

Large title:
28–32 pt
Bold/Semibold

Screen title:
22–24 pt
Semibold

Section title:
16–18 pt
Semibold

Body:
15–16 pt
Regular

Secondary:
13–14 pt

Caption:
11–12 pt

Не использовать чрезмерно жирный текст.

Заголовки должны иметь визуальный вес, но интерфейс не должен выглядеть как dashboard.

Использовать Dynamic Type.

Не фиксировать размеры текста так, чтобы accessibility ломался.

==================================================
4. ROUNDED CORNERS
==================================================

Система радиусов:

Small:
8 pt

Medium:
12 pt

Large:
16 pt

XL:
20 pt

Conversation/message bubbles:
18–22 pt

Input composer:
22–28 pt

Cards:
16–20 pt

Главный принцип:
интерфейс должен быть мягким и "rounded".

Не использовать стандартные прямоугольные SwiftUI List/Form rows.

==================================================
5. MAIN CONVERSATION SCREEN
==================================================

Это главный экран приложения.

Композиция сверху вниз:

--------------------------------
TOP BAR
--------------------------------

В верхней части:

слева:
hamburger/menu button

по центру:
"New Conversation"

справа:
compose/new conversation icon

Top bar должен быть визуально лёгким.

Не делать navigation bar тяжёлым.

Высота примерно 52–60 pt.

Иконки:
тонкие SF Symbols.

--------------------------------
PROVIDER SELECTOR
--------------------------------

Под top bar:

небольшой pill.

Пример:

[ 🟢 OmniRoute  > ]

Pill должен быть:
- compact;
- rounded;
- elevated;
- subtle background;
- небольшая border;
- green status dot;
- название provider;
- chevron.

Это НЕ должна быть огромная кнопка.

Высота примерно 34–38 pt.

Provider selector располагается отдельно от navigation bar.

--------------------------------
CONVERSATION AREA
--------------------------------

Основная область занимает почти весь экран.

Важно:
не делать огромные пустые пространства.

Messages располагаются с естественными отступами.

User message:
- справа;
- purple gradient / purple accent surface;
- белый текст;
- rounded corners;
- bubble визуально компактный;
- максимум разумной ширины, не на весь экран.

Assistant message:
- слева;
- dark elevated surface;
- subtle border;
- мягкая shadow;
- белый/светло-серый текст;
- комфортный line spacing.

Assistant bubble НЕ должен выглядеть как яркая карточка.

Message width:
примерно 75–85% экрана максимум.

Spacing:
8–14 pt между сообщениями.

Не превращать каждый message в огромную карточку.

--------------------------------
MESSAGE ACTIONS
--------------------------------

Под assistant message могут появляться:

copy
like
dislike
more

Но они должны быть компактными.

Не делать отдельные большие кнопки.

Использовать SF Symbols.

Actions появляются unobtrusively.

--------------------------------
COMPOSER
--------------------------------

КРИТИЧЕСКИ ВАЖНО.

Текущий composer занимает слишком много вертикального пространства.
Это необходимо исправить.

Composer должен быть компактным и напоминать современный AI chat composer.

Он располагается внизу экрана.

Основная форма:

[ attachment ] [ Message Omnia...                         ] [ send ]

Внешний контейнер:
- rounded capsule / rounded rectangle;
- dark elevated background;
- subtle border;
- soft shadow.

Высота:
примерно 50–58 pt в состоянии одной строки.

При вводе текста:
- composer расширяется вертикально;
- примерно 1–6 строк;
- после этого начинает внутренний scroll.

НЕ делать composer высотой 30–50% экрана.

Обычное состояние:
около 50–60 pt.

Placeholder:
"Message Omnia..."

Placeholder muted.

Attachment:
маленькая icon button.

Send:
круглая accent button;
purple;
SF Symbol arrow.up.

Composer должен ощущаться как единый control.

Не делать:
- огромный TextEditor;
- огромный пустой padding;
- отдельную большую кнопку Send;
- composer, который визуально выглядит как Form.

Keyboard handling должен оставаться корректным.

==================================================
6. CONVERSATION LIST
==================================================

Экран Conversations.

Top:

hamburger/menu
center title:
"Conversations"
right:
new conversation

Под title:
search field.

Search:
dark elevated rounded capsule.

Placeholder:
"Search conversations..."

Далее группировка:

Today

Yesterday

Previous 7 Days

Каждая conversation:

иконка conversation
title
preview
timestamp / relative date
chevron

Rows:
примерно 64–72 pt.

Между группами:
24–32 pt.

Не использовать стандартный SwiftUI List appearance.

Background:
тот же dark background.

Rows:
очень subtle elevated cards / surfaces.

Selected/pressed state:
subtle accent background.

==================================================
7. PROVIDERS SCREEN
==================================================

Screen title:
"Providers"

Top bar:
hamburger
Providers
+

Active provider выделяется отдельно.

Пример:

Active Provider

[ purple provider icon ]
OmniRoute
https://...
[ Active ]

Card:
dark elevated surface;
rounded corners 16–20;
subtle border.

Status:
green pill "Active".

Другие providers:

OpenAI
Local AI
Staging

Каждый provider:
- icon;
- name;
- endpoint;
- overflow menu "..."
- status indicator.

Не использовать стандартные Settings List rows.

Providers должны выглядеть как premium cards.

==================================================
8. SIDE MENU / ROOT NAVIGATION
==================================================

Navigation drawer/menu должен выглядеть как native modern iOS side panel.

Items:

New Chat
Conversations
Providers
Settings
About

Каждый item:
icon + title.

Selected:
subtle purple background;
rounded 12–14.

Не использовать огромные icons.

Spacing generous.

Внизу:

Dark Mode toggle.

Toggle должен быть компактным.

==================================================
9. SETTINGS
==================================================

Settings должен использовать ту же design language.

Не использовать стандартный iOS Form appearance.

Sections должны быть visual cards.

Каждый setting:

label
description/value
accessory

Например:

Appearance
Dark Mode
...

Provider
Default provider
...

About

Все surfaces:
dark elevated.

==================================================
10. EMPTY STATES
==================================================

Empty state должен выглядеть premium.

В центре:

иконка/символ Omnia

заголовок:

"Start a new conversation"

subtitle:

"Ask anything, get answers."

Можно использовать subtle purple/cyan glow.

Но glow должен быть очень мягким.

Не делать огромную иллюстрацию.

==================================================
11. ERROR STATE
==================================================

Error card:

красный/оранжевый subtle accent.

Icon:
error / exclamation

Title:
"Failed to connect to provider"

Description:
"Please check your connection and try again."

Action:
retry icon/button.

Ошибка не должна быть screaming red.

Использовать dark red tinted surface.

==================================================
12. THINKING / STREAMING STATES
==================================================

Thinking:

card:
dark elevated surface

icon:
sparkle / AI symbol

Title:
"Thinking"

Subtitle:
"Omnia is thinking"

Streaming:

Title:
"Streaming"

Subtitle:
"Omnia is typing"

Справа:
animated indicator.

Animation:
subtle.

Не использовать flashy animation.

==================================================
13. LIGHT THEME
==================================================

Light theme также должен существовать.

Не просто invert colors.

Light theme:

background:
#F7F8FA / near-white

surface:
#FFFFFF

elevated:
#F1F3F7

border:
#D9DEE8

primary text:
#171A21

secondary:
#667085

Accent:
purple.

User message:
purple accent.

Assistant:
light gray elevated surface.

Важно:
Dark theme остаётся главным визуальным identity.

==================================================
14. OMNIA BRANDING
==================================================

Omnia branding:

Большой символ O.

Логотип:
круговая/кольцевая форма с gradient purple → cyan.

Не превращать интерфейс в логотипный фестиваль.

Logo используется:
- launch/onboarding;
- empty states;
- About;
- возможно provider identity.

Основной UI остаётся минимальным.

==================================================
15. ICONOGRAPHY
==================================================

Использовать SF Symbols.

Основные:

menu:
line.3.horizontal

new chat:
square.and.pencil

conversation:
bubble.left

providers:
network / server / circle

settings:
gearshape

about:
info.circle

attachment:
paperclip

send:
arrow.up

copy:
doc.on.doc

like:
hand.thumbsup

dislike:
hand.thumbsdown

more:
ellipsis

search:
magnifyingglass

retry:
arrow.clockwise

dark mode:
moon

light mode:
sun.max

success:
checkmark.circle

error:
exclamationmark.triangle

Иконки:
тонкие;
consistent size;
обычно 18–22 pt.

==================================================
16. DESIGN SYSTEM / REUSABLE COMPONENTS
==================================================

Не реализовывать каждый экран независимо.

Создать/использовать reusable components:

OmniaBackground
OmniaCard
OmniaButton
OmniaIconButton
OmniaPill
ProviderSelector
MessageBubbleView
ComposerView
ConversationRow
ProviderRow
EmptyStateView
ErrorBannerView
StatusIndicator
SectionHeader

Все они должны использовать единые DesignTokens.

==================================================
17. VISUAL HIERARCHY
==================================================

Приоритет:

1. Conversation content
2. Composer
3. Provider context
4. Navigation
5. Secondary actions

Не наоборот.

Главный экран должен выглядеть как AI chat application,
а не как Settings application.

==================================================
18. SPACING SYSTEM
==================================================

Использовать единый spacing scale:

4
8
12
16
20
24
32
40

Не использовать случайные значения вроде:
7
13
19
27

если это не требуется конкретной native layout причиной.

Основной horizontal screen padding:
16–20 pt.

Cards:
16–20 pt.

==================================================
19. RESPONSIVE / DEVICE BEHAVIOR
==================================================

Обязательно учитывать:

iPhone SE
обычный iPhone
Pro Max
iPad если target поддерживает.

Safe area.

Keyboard.

Dynamic Type.

Accessibility.

Landscape, если поддерживается.

Composer должен корректно работать при keyboard presentation.

==================================================
20. НЕ ЛОМАТЬ ФУНКЦИОНАЛ
==================================================

После redesign обязательно проверить:

- provider selection;
- OmniRoute;
- conversation creation;
- conversation list;
- message sending;
- streaming;
- errors;
- retry;
- settings;
- localization;
- dark/light theme;
- accessibility;
- keyboard behavior.

Особенно:

OmniRoute integration уже реализована и frozen.

НЕ менять её API/Domain/Application contracts.

==================================================
21. ACCEPTANCE CRITERIA
==================================================

UI считается завершённым только если:

1. Conversation screen визуально соответствует описанному premium AI-client стилю.
2. Composer в обычном состоянии занимает примерно 50–60 pt, а не значительную часть экрана.
3. Composer расширяется только при необходимости.
4. Message bubbles имеют правильную визуальную иерархию.
5. Provider selector является компактным pill.
6. Conversation list выглядит как современный card/list interface.
7. Providers выглядят как cards, а не стандартный Settings List.
8. Settings используют ту же design system.
9. Dark theme выглядит цельно.
10. Light theme не является простым inversion.
11. Все основные элементы используют semantic design tokens.
12. Нет случайных hardcoded цветов/spacing.
13. SF Symbols используются последовательно.
14. Все существующие UX-контракты сохранены.
15. OmniRoute integration продолжает работать.
16. Все существующие тесты проходят.
17. SwiftUI preview/build не содержит ошибок.
18. Нет regressions в navigation.
19. Нет regressions в localization.
20. Нет regressions в accessibility.

==================================================
22. WORKFLOW
==================================================

Сначала:

1. Изучи существующий Presentation слой.
2. Найди уже существующие UI components.
3. Найди существующую design-token систему.
4. Не создавай дубликаты компонентов.
5. Составь UI_REDESIGN_PLAN.md.
6. Реализуй redesign.
7. После каждого крупного блока запускай тесты.
8. В конце запусти полный test suite.
9. Создай:

Documentation/Development/UI_REDESIGN_FINAL.md

В отчёте обязательно указать:

- какие экраны изменены;
- какие components созданы/переиспользованы;
- какие design tokens добавлены;
- как реализован composer;
- как обеспечена responsive behavior;
- какие acceptance criteria выполнены;
- результаты тестов;
- какие ограничения остались.

ВАЖНО:

НЕ commit.
НЕ push.
НЕ merge.

После завершения остановись и покажи отчёт.

Я сам проверю UI на физическом iPhone.

==================================================
23. ОСОБЕННО ВАЖНЫЕ ПРИОРИТЕТЫ
==================================================

При конфликте требований приоритет:

1. Existing architecture / frozen contracts.
2. Existing UX contracts.
3. Functional behavior.
4. Visual design.
5. Pixel-level similarity.

Но визуально нужно стремиться максимально близко к описанному концепту.

Главное изменение по сравнению с текущим UI:

Текущий Omnia должен перестать выглядеть как набор стандартных SwiftUI экранов.

Он должен выглядеть как единый продукт с одной design system.

Conversation screen — главный приоритет.

Особое внимание:
COMPOSER.

Он должен быть компактным, современным, rounded и визуально интегрированным в экран.

Не допускается ситуация, когда поле ввода занимает половину экрана в обычном состоянии.

CRITICAL VISUAL RULE:

Do NOT interpret "redesign" as:
- increasing padding everywhere;
- adding shadows;
- changing a few colors;
- changing TextField to TextEditor;
- adding rounded corners;
- adding Material backgrounds.

That is insufficient.

The goal is a SYSTEMATIC redesign of the Presentation layer:
layout + hierarchy + spacing + typography + surfaces + components + states + navigation + composer + cards + semantic tokens.

If an existing screen structurally prevents the target visual hierarchy, refactor its SwiftUI layout rather than applying cosmetic modifiers to the existing hierarchy.