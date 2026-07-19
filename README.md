# AuroraUI

Fluent/Mica-вдохновлённая UI-библиотека для Roblox (LuaU), в духе **WPF UI** для .NET —
но полностью переписанная под Roblox с нуля (прямой порт C#/XAML невозможен, Roblox
использует другой движок интерфейса).

Чем отличается от типовых Rayfield/Fluent-клонов:

- **"Mica"-слоистый фон** — мягкий диагональный градиент accent → base вместо плоской заливки.
- **Акцентное свечение** вместо жёстких белых бордеров (обводки на 8–12% непрозрачности).
- **Пружинная анимация** (`Enum.EasingStyle.Back`/`Quint`) вместо линейных твинов — окно, свитчи и уведомления слегка "пружинят".
- **Ripple-эффект** на кнопках (круговая волна из точки клика, как в Fluent Design).
- Один файл, никаких внешних ассетов/шрифтов — работает из коробки.

## Установка

### Вариант 1: GitHub + loadstring (быстрее всего)

1. Залейте `src/AuroraUI.lua` в свой репозиторий на GitHub.
2. Нажмите **Raw** на файле и скопируйте ссылку вида:
   `https://raw.githubusercontent.com/USERNAME/REPO/main/AuroraUI.lua`
3. В своём скрипте (например, в exploit-консоли или LocalScript с HTTP-доступом):

```lua
local AuroraUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/USERNAME/REPO/main/AuroraUI.lua"))()
```

### Вариант 2: ModuleScript внутри игры

1. Создайте `ModuleScript` в `ReplicatedStorage` (или `StarterPlayerScripts`), назовите `AuroraUI`.
2. Вставьте туда содержимое `src/AuroraUI.lua`.
3. В `LocalScript`:

```lua
local AuroraUI = require(game.ReplicatedStorage.AuroraUI)
```

## Быстрый старт

```lua
local Window = AuroraUI:CreateWindow({
    Title = "Моя панель",
    SubTitle = "v1.0",
    Theme = "Midnight",             -- "Midnight" или "Dawn"
    Size = UDim2.fromOffset(620, 420),
    ToggleKey = Enum.KeyCode.RightControl, -- скрыть/показать окно
})

local Tab = Window:CreateTab({ Name = "Главная", Icon = "🏠" })

Tab:AddButton({
    Name = "Нажми меня",
    Callback = function()
        Window:Notify({ Title = "Готово", Content = "Кнопка нажата", Type = "Success" })
    end,
})

Tab:AddToggle({
    Name = "Автобег",
    Default = false,
    Flag = "AutoRun",
    Callback = function(state) print(state) end,
})

Tab:AddSlider({
    Name = "Скорость",
    Min = 16, Max = 200, Default = 16,
    Flag = "WalkSpeed",
    Callback = function(v)
        game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = v
    end,
})
```

Полный рабочий пример со всеми компонентами — в `src/Example.lua`.

## API

### `AuroraUI:CreateWindow(config)`
| Поле | Тип | Описание |
|---|---|---|
| `Title` | string | Заголовок окна |
| `SubTitle` | string | Подзаголовок под заголовком |
| `Theme` | `"Midnight"` \| `"Dawn"` | Тёмная или светлая тема |
| `Size` | UDim2 | Размер окна (по умолчанию 620×420) |
| `ToggleKey` | Enum.KeyCode | Клавиша скрытия/показа GUI |

Возвращает объект окна с методами `CreateTab`, `Notify`, полем `Flags` (таблица со всеми значениями компонентов по ключу `Flag`, удобно для сохранения конфигов).

### `Window:CreateTab({ Name, Icon })`
Возвращает объект вкладки с методами:

- `:AddButton({ Name, Callback })`
- `:AddToggle({ Name, Default, Flag, Callback })`
- `:AddSlider({ Name, Min, Max, Default, Increment, Suffix, Flag, Callback })`
- `:AddDropdown({ Name, Options, Default, Flag, Callback })`
- `:AddTextbox({ Name, Placeholder, Default, Flag, Callback })`
- `:AddParagraph({ Title, Content })`
- `:AddLabel(text)`

Каждый компонент (кроме Label/Paragraph) возвращает `{ Set(value), Get() }` для программного управления.

### `Window:Notify({ Title, Content, Type, Duration })`
`Type`: `"Info"` / `"Success"` / `"Warning"` / `"Danger"`. Всплывающее уведомление в правом нижнем углу.

## Кастомизация темы

Темы лежат в `AuroraUI.Themes`. Можно добавить свою:

```lua
AuroraUI.Themes.Custom = {
    Base = Color3.fromRGB(15, 15, 20),
    Layer1 = Color3.fromRGB(22, 22, 30),
    Layer2 = Color3.fromRGB(28, 28, 38),
    Layer3 = Color3.fromRGB(36, 36, 48),
    Stroke = Color3.fromRGB(255,255,255),
    Text = Color3.fromRGB(240,240,245),
    SubText = Color3.fromRGB(150,150,165),
    Accent = Color3.fromRGB(255, 90, 140),
    AccentDim = Color3.fromRGB(200, 70, 110),
    Success = Color3.fromRGB(95,210,140),
    Warning = Color3.fromRGB(240,180,80),
    Danger = Color3.fromRGB(235,95,110),
}
```
и затем `Theme = "Custom"` при создании окна.

## Лицензия

MIT — свободно используйте, изменяйте и распространяйте.
