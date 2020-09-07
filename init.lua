hs.loadSpoon("WinWin")
hs.loadSpoon("WindowGrid")
hs.loadSpoon("WindowHalfsAndThirds")
hs.loadSpoon("KSheet")
-- hs.loadSpoon("Seal")
hs.loadSpoon("SpoonInstall")
hs.loadSpoon("AClock")
-- hs.loadSpoon("HCalendar")
hs.loadSpoon("CountDown")
hs.loadSpoon("HSKeybindings")
-- hs.loadSpoon("TimeFlow")

Install=spoon.SpoonInstall

local hyper = {'ctrl', 'cmd'}

local alert = require 'hs.alert'
local application = require 'hs.application'
local geometry = require 'hs.geometry'
local grid = require 'hs.grid'
local hints = require 'hs.hints'
local hotkey = require 'hs.hotkey'
local layout = require 'hs.layout'
local window = require 'hs.window'
local speech = require 'hs.speech'

-- Init speaker.
speaker = speech.new()

-- Init.
hs.window.animationDuration = 0 -- don't waste time on animation when resize window

-- Key to launch application.
local key2App = {
    j = {'/Applications/Firefox Developer Edition.app', 'English'},
    h = {'/Applications/Visual Studio Code.app', 'English'},
    t = {'/System/Applications/Utilities/Terminal.app', 'English'},
    l = {'/Applications/PhpStorm.app','English'},
    w = {'/Applications/WeChat.app', 'Chinese'},
    e = {'/Applications/Safari.app', 'English'},
    s = {'/Applications/Sublime Text.app', 'English'},
    k = {'/Applications/Sourcetree.app', 'English'},
}

-- Show launch application's keystroke.
local showAppKeystrokeAlertId = ""

local function showAppKeystroke()
    if showAppKeystrokeAlertId == "" then
        -- Show application keystroke if alert id is empty.
        local keystroke = ""
        local keystrokeString = ""
        for key, app in pairs(key2App) do
            keystrokeString = string.format("%-10s%s", key:upper(), app[1]:match("^.+/(.+)$"):gsub(".app", ""))

            if keystroke == "" then
                keystroke = keystrokeString
            else
                keystroke = keystroke .. "\n" .. keystrokeString
            end
        end

        showAppKeystrokeAlertId = hs.alert.show(keystroke, hs.alert.defaultStyle, hs.screen.mainScreen(), 10)
    else
        -- Otherwise hide keystroke alert.
        hs.alert.closeSpecific(showAppKeystrokeAlertId)
        showAppKeystrokeAlertId = ""
    end
end

hs.hotkey.bind(hyper, "z", showAppKeystroke)


-- Build better app switcher.
switcher = hs.window.switcher.new(
    hs.window.filter.new()
        :setAppFilter('Emacs', {allowRoles = '*', allowTitles = 1}), -- make emacs window show in switcher list
    {
        showTitles = false,               -- don't show window title
        thumbnailSize = 200,              -- window thumbnail size
        showSelectedThumbnail = false,    -- don't show bigger thumbnail
        backgroundColor = {0, 0, 0, 0.8}, -- background color
        highlightColor = {0.3, 0.3, 0.3, 0.8}, -- selected color
    }
)

hs.hotkey.bind("alt", "tab", function()
		   switcher:next()
		   updateFocusAppInputMethod()
end)
hs.hotkey.bind("alt-shift", "tab", function()
		   switcher:previous()
		   updateFocusAppInputMethod()
end)

function updateFocusAppInputMethod()

end

-- Handle cursor focus and application's screen manage.
startAppPath = ""
function applicationWatcher(appName, eventType, appObject)
    -- Move cursor to center of application when application activated.
    -- Then don't need move cursor between screens.
    if (eventType == hs.application.watcher.activated) then
        -- Just adjust cursor postion if app open by user keyboard.
        if appObject:path() == startAppPath then
            spoon.WinWin:centerCursor()
            startAppPath = ""
        end
    end
end

appWatcher = hs.application.watcher.new(applicationWatcher)
appWatcher:start()

function findApplication(appPath)
    local apps = application.runningApplications()
    for i = 1, #apps do
        local app = apps[i]
        if app:path() == appPath then
            return app
        end
    end

    return nil
end

function launchApp(appPath)
    -- We need use Chrome's remote debug protocol that debug JavaScript code in Emacs.
    -- So we need launch chrome with --remote-debugging-port argument instead application.launchOrFocus.
    if appPath == "/Applications/Google Chrome.app" then
        hs.execute("open -a 'Google Chrome' --args '--remote-debugging-port=9222'")
    else
        application.launchOrFocus(appPath)
    end
end

-- Toggle an application between being the frontmost app, and being hidden
function toggleApplication(app)
    local appPath = app[1]
    local inputMethod = app[2]

    -- Tag app path use for `applicationWatcher'.
    startAppPath = appPath

    local app = findApplication(appPath)
    local setInputMethod = true

    if not app then
        -- Application not running, launch app
        launchApp(appPath)
    else
        -- Application running, toggle hide/unhide
        local mainwin = app:mainWindow()
        if mainwin then
            if app:isFrontmost() then
                -- Show mouse circle if has focus on target application.
                drawMouseCircle()
                mainwin.application():hide()
                setInputMethod = false
            else
                -- Focus target application if it not at frontmost.
                mainwin:application():activate(true)
                mainwin:application():unhide()
                mainwin:focus()
            end
        else
            -- Start application if application is hide.
            if app:hide() then
                launchApp(appPath)
            end
        end
    end
end

local mouseCircle = nil
local mouseCircleTimer = nil

function drawMouseCircle()
    -- Kill previous circle if it still live.
    circle = mouseCircle
    timer = mouseCircleTimer

    if circle then
        circle:delete()
        if timer then
            timer:stop()
        end
    end

    -- Get mouse point.
    mousepoint = hs.mouse.getAbsolutePosition()

    -- Init circle color and raius.
    local color = {
        ["red"]= 92.0 / 255.0,
        ["blue"]= 245.0 / 255.0,
        ["green"]= 201.0 / 255.0,
        ["alpha"]= 0.8}

    raius = 30

    -- Draw mouse circle.
    circle = hs.drawing.circle(hs.geometry.rect(mousepoint.x - raius / 2, mousepoint.y - raius / 2, raius, raius))
    circle:setStroke(false)
    circle:setFillColor(color)
    circle:bringToFront(true)
    circle:show()

    -- Save circle in local variable.
    mouseCircle = circle

    -- Hide mouse circle after 0.5 second.
    mouseCircleTimer = hs.timer.doAfter(
        0.5,
        function()
            circle:hide(0.5)
            hs.timer.doAfter(0.6, function() circle:delete() end)
    end)
end



moveToScreen = function(win, n)
    local screens = hs.screen.allScreens()
    if n > #screens then
        hs.alert.show("No enough screens " .. #screens)
    else
        local toWin = hs.screen.allScreens()[n]:name()
        hs.alert.show("Move " .. win:application():name() .. " to " .. toWin)
        hs.layout.apply({{nil, win:title(), toWin, hs.layout.maximized, nil, nil}})
    end
end

function resizeToFullWindow()
    local win = hs.window.focusedWindow()
    local f = win:frame()
    local screen = win:screen()
    local max = screen:frame()
    local winScale = 0.9

    f.x = max.x
    f.y = max.y
    f.w = max.w
    f.h = max.h
    win:setFrame(f)
end
hs.hotkey.bind(hyper, 'N', resizeToFullWindow)

function resizeToCenter()
    local win = hs.window.focusedWindow()
    local f = win:frame()
    local screen = win:screen()
    local max = screen:frame()
    local winScale = 0.9

    f.x = max.x + (max.w * (1 - winScale) / 2)
    f.y = max.y + (max.h * (1 - winScale) / 2)
    f.w = max.w * winScale
    f.h = max.h * winScale
    win:setFrame(f)
end

-- Window operations.
hs.hotkey.bind(hyper, 'U', resizeToCenter)

hs.hotkey.bind(
    hyper, "Y",
    function()
        window.focusedWindow():moveToUnit(layout.left50)
end)

hs.hotkey.bind(
    hyper, "R",
    function()
        window.focusedWindow():moveToUnit(layout.right50)
end)


hs.hotkey.bind(
    hyper, ".",
    function()
        hs.alert.show(string.format("App path:        %s\nApp name:      %s\nIM source id:  %s",
                                    window.focusedWindow():application():path(),
                                    window.focusedWindow():application():name(),
                                    hs.keycodes.currentSourceID()))
end)

hotkey.bind(
    hyper, '/',
    function()
        hints.windowHints()
end)

-- Start or focus application.
for key, app in pairs(key2App) do
    hotkey.bind(
        hyper, key,
        function()
            toggleApplication(app)
    end)
end

-- Binding key to start plugin.
Install:andUse(
    "WindowHalfsAndThirds",
    {
        config = {use_frame_correctness = true},
        hotkeys = {max_toggle = {hyper, "I"}}
})

Install:andUse(
    "WindowGrid",
    {
        config = {gridGeometries = {{"6x4"}}},
        hotkeys = {show_grid = {hyper, ","}},
        start = true
})

-- Show application keystroke window.
local ksheetIsShow = false
local ksheetAppPath = ""

hs.hotkey.bind(
    hyper, "M",
    function ()
        local currentAppPath = window.focusedWindow():application():path()

        -- Toggle ksheet window if cache path equal current app path.
        if ksheetAppPath == currentAppPath then
            if ksheetIsShow then
                spoon.KSheet:hide()
                ksheetIsShow = false
            else
                spoon.KSheet:show()
                ksheetIsShow = true
            end
            -- Show app's keystroke if cache path not equal current app path.
        else
            spoon.KSheet:show()
            ksheetIsShow = true

            ksheetAppPath = currentAppPath
        end
end)


-- Reload config.
hs.hotkey.bind(
    hyper, "'", function ()
        speaker:speak("Cover me, reloading...")
        hs.reload()
end)

-- We put reload notify at end of config, notify popup mean no error in config.
hs.notify.new({title="NEST", informativeText="Boss, I am online!"}):send()

-- Speak something after configuration success.
speaker:speak("Boss, I am online!")
hs.hotkey.bind(
    hyper, "C",function()
    spoon.AClock:toggleShow()
end)
