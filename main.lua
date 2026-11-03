local Label = LibScrollList.Label
local Texture = LibScrollList.Texture
local Table = LibScrollList.Table
local Column = LibScrollList.Column
local Button = LibScrollList.Button
local combine = LibScrollList.combine

-- ----------------------------------------------------------------------------

local DefaultAddOnManager = GetAddOnManager()

local ENABLED_INDEX = 5

local addonBuffer = {}
GLOBAL_ADDON_BUFFER = addonBuffer

-- local AddonManagerWrapper = {}
-- AddonManagerWrapper.__index = AddonManagerWrapper

-- function AddonManagerWrapper:__init()
--     self.buffer = {}


-- end

-- function AddonManagerWrapper:GetAddOnInfo(index)
--     if not self.buffer[index] then
--         self.buffer = { DefaultAddOnManager:GetAddOnInfo(index) }
--     end

--     return self.buffer[index]
-- end

local DefaultGetAddonInfo = DefaultAddOnManager.GetAddOnInfo
local DefaultSetAddOnEnabled = DefaultAddOnManager.SetAddOnEnabled

-- SetAddOnEnabled(*luaindex* _addOnIndex_, *bool* _enabled_)

DefaultAddOnManager.GetAddOnInfo = function(self, index)
    if not addonBuffer[index] then
        addonBuffer[index] = { DefaultGetAddonInfo(self, index) }
    end

    return unpack(addonBuffer[index])
end

DefaultAddOnManager.SetAddOnEnabled = function(self, index, enabled)
    if addonBuffer[index] then
        addonBuffer[index][ENABLED_INDEX] = enabled
    end

    DefaultSetAddOnEnabled(self, index, enabled)
end

-- ----------------------------------------------------------------------------

local addon = {
    name = 'ImprovedAddonList',
}

local EVENT_NAMESPACE = addon.name
local ADDON_MANAGER = GetAddOnManager()


local NAME = 1
local TITLE = 2
local AUTHOR = 3
local DESCRIPTION = 4
local ENABLED = 5
local STATE = 6
local IS_LIBRARY = 8
local NUM_DEPENDENCIES = 10


local CUSTOM_STATE_ON = 1
local CUSTOM_STATE_OFF = 2
local CUSTOM_STATE_ERROR = 3

local function __getState(enabled, trueState)
    if enabled then
        if trueState == ADDON_STATE_DEPENDENCIES_DISABLED then
            return CUSTOM_STATE_ERROR
        end

        return CUSTOM_STATE_ON
    else
        return CUSTOM_STATE_OFF
    end
end

local CUSTOM_STATE_NAMES = {
    [CUSTOM_STATE_ON]    = 'ON',
    [CUSTOM_STATE_OFF]   = 'OFF',
    [CUSTOM_STATE_ERROR] = 'ERR',
}

local function getStateLabel(state)
-- local function getStateLabel(enabled, state)
    -- if enabled then
    --     if state == ADDON_STATE_DEPENDENCIES_DISABLED then
    --         return 'ERR'
    --     end

    --     return 'ON'
    -- else
    --     return 'OFF'
    -- end

    return CUSTOM_STATE_NAMES[state]
end

local function getStateColor(state)
    if state == CUSTOM_STATE_ON then
        return 0, 1, 0, 1
    elseif state == CUSTOM_STATE_OFF then
        return 0.7, 0.7, 0.7, 1
    elseif state == CUSTOM_STATE_ERROR then
        return 1, 0, 0, 1
    end
end

-- TODO: get rid of color, depName, details
local function _formatAddonNameInTooltip(name, exists, active, version, minVersion)
    local color, details
    if not exists then
        color = 'FF0000'
        details = ' (missing)'
        -- counterMissing = counterMissing + 1
    else
        if active then
            if version < minVersion then
                color = 'FF0000'
                details = ' (newer version required)'
                -- counterOldVersion = counterOldVersion + 1
            else
                color = '00FF00'
                details = ''
            end
        else
            color = 'B3B3B3'
            details = ' (disabled)'
            -- counterDisabled = counterDisabled + 1
        end
    end

    return ('- |c%s%s%s|r'):format(color, name, details)
end

function addon:CreateTable()
    local defaultCellStyle = {
        SetFont = {'ZoFontWinH4'},
        SetVerticalAlignment = {TEXT_ALIGN_CENTER},
        SetWrapMode = {TEXT_WRAP_MODE_ELLIPSIS},
        SetMaxLineCount = {1},
    }

    local defaultHeaderStyle = {
        -- SetFont = {'ZoFontGameLargeBold'},
        SetColor = {0.811, 0.862, 0.741},
        SetModifyTextType = {MODIFY_TEXT_TYPE_UPPERCASE},
    }

    local alignLeft = {SetHorizontalAlignment = {TEXT_ALIGN_LEFT}}
    local alignCenter = {SetHorizontalAlignment = {TEXT_ALIGN_CENTER}}
    local alignRight = {SetHorizontalAlignment = {TEXT_ALIGN_RIGHT}}

    -- local addQty = function(ctrl, value) ctrl:SetText(('%s pcs'):format(value)) end  -- setFn to modify value

    local Right = Label(combine(defaultCellStyle, alignRight))  -- combine can be used to combine styles
    -- local IndexCell = Label(combine(defaultCellStyle, alignRight))  -- combine can be used to combine styles
    local Left = Label(combine(defaultCellStyle, alignLeft))
    local Center = Label(combine(defaultCellStyle, alignCenter))

    local Tags = Label(combine(defaultCellStyle, alignRight), function(ctrl, value)
        local tmp = {}
        local addonIndex = ctrl:GetParent().dataEntry.data[1]
        local addonName = self.addonList[addonIndex][NAME]
        for tagIndex, added in pairs(self.addonTags[addonName]) do
            if added then tmp[#tmp+1] = self.tags[tagIndex] end
        end

        ctrl:SetText(#tmp > 0 and table.concat(tmp, ', ') or '-')
    end)

    local CenterHeader = Label(combine(combine(defaultCellStyle, alignCenter), defaultHeaderStyle))
    local RightHeader = Label(combine(combine(defaultCellStyle, alignRight), defaultHeaderStyle))
    -- local QtyCell = Label(combine(defaultCellStyle, alignRight))

    local function useFullTitle(ctrl, value)
        local addonIndex = ctrl:GetParent().dataEntry.data[1]
        local fullTitle = self.addonList[addonIndex][TITLE]

        ctrl:SetText(fullTitle)
    end

    local Title = Label(combine(defaultCellStyle, alignLeft), useFullTitle)
    local TitleHeader = Label(combine(combine(defaultCellStyle, alignLeft), defaultHeaderStyle))
    local LeftHeader = Label(combine(combine(defaultCellStyle, alignLeft), defaultHeaderStyle))

    -- local IdHeader = Label(combine(defaultHeaderStyle, alignRight))
    -- local NameHeader = Label(combine(defaultHeaderStyle, alignLeft))


    local stateTooltipText = [[
- |c00FF00ON|r - Addon is |c00FF00ON|r and works normally
- |cB3B3B3OFF|r - Addon is set to |cB3B3B3OFF|r
- |cFF0000ERR|r - Addon is set to |c00FF00ON|r, but doesn't work because of some error

Check if all dependencies exist, have compatible version and turned |c00FF00ON|r.

Tip: If dependencies are turned |cB3B3B3OFF|r, click on the button to turn them automatically |c00FF00ON|r.]]

    local stateTooltip = {
        {'SetHandler', 'OnMouseEnter', function(ctrl) ZO_Tooltips_ShowTextTooltip(ctrl, TOP, stateTooltipText) end},
        {'SetHandler', 'OnMouseExit', ZO_Tooltips_HideTextTooltip}
    }

    local StateHeader = Label(combine(combine(combine(defaultCellStyle, defaultHeaderStyle), alignCenter), stateTooltip))

    --[[
    local STATE_NAMES = {
        [ADDON_STATE_DEPENDENCIES_DISABLED]      = 'DEPENDENCIES_DISABLED',
        [ADDON_STATE_DISABLED]                   = 'DISABLED',
        [ADDON_STATE_ENABLED]                    = 'ENABLED',
        [ADDON_STATE_ERROR_STATE_UNABLE_TO_LOAD] = 'ERROR_STATE_UNABLE_TO_LOAD',
        [ADDON_STATE_NO_STATE]                   = 'NO_STATE',
        [ADDON_STATE_TOC_LOADED]                 = 'TOC_LOADED',
        [ADDON_STATE_VERSION_MISMATCH]           = 'VERSION_MISMATCH',
    }
    --]]

    local function lighter(r, g, b, a)
        return r + 0.1, g + 0.1, b + 0.1, a
    end

    -- local function getStateLabel(enabled, state)
    --     if enabled then
    --         if state == ADDON_STATE_DEPENDENCIES_DISABLED then
    --             return 'ERR'
    --         end

    --         return 'ON'
    --     else
    --         return 'OFF'
    --     end
    -- end

    -- local function getStateColor(enabled, state)
    --     if enabled then
    --         if state == ADDON_STATE_DEPENDENCIES_DISABLED then
    --             return 1, 0, 0, 1
    --         end

    --         return 0, 1, 0, 1
    --     else
    --         return 0.7, 0.7, 0.7, 1
    --     end
    -- end

    local function _setState(lbl)
        -- local index = lbl:GetParent():GetParent():GetParent().dataEntry.data[1]
        -- local enabled, state = select(5, ADDON_MANAGER:GetAddOnInfo(index))

        -- local customState = __getState(enabled, state)

        local customState = lbl:GetParent():GetParent():GetParent().dataEntry.data[2]

        lbl:SetText(getStateLabel(customState))
        lbl:SetColor(getStateColor(customState))
    end

    local function _getAddonEnabled(lbl)
        local index = lbl:GetParent():GetParent():GetParent().dataEntry.data[1]  -- TODO: simplify a bit...
        return select(5, ADDON_MANAGER:GetAddOnInfo(index))
    end

    local function onMouseOverButtonLabel(lbl)
        -- local enabled, state = _getAddonEnabled(lbl)
        -- local customState = __getState(enabled, state)

        local customState = lbl:GetParent():GetParent():GetParent().dataEntry.data[2]

        lbl:SetColor(lighter(getStateColor(customState)))
        -- lbl:SetColor(unpack(COLORS[enabled][true]))

        local row = lbl:GetParent():GetParent():GetParent()
        local handler = row:GetHandler('OnMouseEnter')
        if handler then
            handler(row)
        end
    end

    local function onMouseExitButtonLabel(lbl)
        -- local enabled, state = _getAddonEnabled(lbl)
        -- local customState = __getState(enabled, state)

        local customState = lbl:GetParent():GetParent():GetParent().dataEntry.data[2]

        lbl:SetColor(getStateColor(customState))

        local row = lbl:GetParent():GetParent():GetParent()
        local handler = row:GetHandler('OnMouseExit')
        if handler then
            handler(row)
        end
    end

    local function onMouseUpButtonLabel(lbl)
        local addonIndex = lbl:GetParent():GetParent():GetParent().dataEntry.data[1]  -- TODO: simplify a bit...
        -- local enabled, state = select(5, ADDON_MANAGER:GetAddOnInfo(addonIndex))
        -- local customState = __getState(enabled, state)

        local customState = lbl:GetParent():GetParent():GetParent().dataEntry.data[2]

        local nextEnabled
        -- if customState == CUSTOM_STATE_ERROR then
        --     if self.addonList[addonIndex].missing == 0 and self.addonList[addonIndex].old == 0 then
        --         nextEnabled = true
        --     else
        --         nextEnabled = false
        --     end
        -- else
        --     if customState == CUSTOM_STATE_ON then
        --         nextEnabled = false
        --     elseif customState == CUSTOM_STATE_OFF then
        --         nextEnabled = true
        --     end
        -- end
        if customState == CUSTOM_STATE_ON then
            nextEnabled = false
        elseif customState == CUSTOM_STATE_OFF then
            nextEnabled = true
        end

        ADDON_MANAGER:SetAddOnEnabled(addonIndex, nextEnabled)
        df('Setting addon %d %s', addonIndex, tostring(nextEnabled))

        _setState(lbl)

        if nextEnabled then  -- TODO: event system to avoid direct dependency
            self:CheckIfLibrariesShouldBeTurnedOn(addonIndex)
        else
            self:CheckIfLibrariesCanBeTurnedOff(addonIndex)
        end

        self:Update()
        self:RefreshKeybinds()
    end

    local function onCreateCallback(bttn)  -- TODO: on init callback?
        local label = bttn:GetNamedChild('Label')
        if not label then
            label = CreateControl('$(parent)Label', bttn, CT_LABEL)
            label:SetAnchor(CENTER, nil, CENTER)
            label:SetFont('ZoFontWinH4')

            label:SetHandler('OnMouseEnter', onMouseOverButtonLabel)
            label:SetHandler('OnMouseExit', onMouseExitButtonLabel)
            label:SetHandler('OnMouseUp', onMouseUpButtonLabel)

            label:SetMouseEnabled(true)
        end

        _setState(label)
    end

    local function toggleCallback(bttn)
        local index = bttn:GetParent():GetParent().dataEntry.data[1]
        local label = bttn:GetNamedChild('Label')

        local name, title, author, description, enabled, state, isOutOfDate, isLibrary = ADDON_MANAGER:GetAddOnInfo(index)

        _setState(label)

        -- if enabled then
        --     label:SetText('ON')
        -- else
        --     label:SetText('OFF')
        -- end

        -- df('Button pressed, addonIndex: %d', index)
        -- TODO: get row -> addon index -> toggle addon state
    end

    local buttonStyle = {
        SetDimensions = {32, 32},
        SetTextureCoords = {0.10, 0.90, 0.10, 0.90},
        SetDrawTier = {DT_MEDIUM},
        SetMouseOverBlendMode = {TEX_BLEND_MODE_ADD},
    }

    local ToggleButton = Button(buttonStyle, onCreateCallback, toggleCallback)

    local LIBRARY_TEXTURE = '/esoui/art/menubar/gamepad/gp_playermenu_icon_lorelibrary.dds'
    local Library = Texture(nil, function(ctrl, value)
        if value == 1 then
            ctrl:SetTexture(LIBRARY_TEXTURE)
            ctrl:SetHidden(false)
        else
            ctrl:SetHidden(true)
        end
    end)

    -- 3. Create list of columns
    local SORTABLE = true
    local columns = {
        Column('Index',   30,  0, Right,            '#', nil,             SORTABLE),
        Column('State',   55, 16, ToggleButton, 'State', StateHeader,     SORTABLE),
        Column('Name',   270,  8, Title,  'Addon Title', TitleHeader,     SORTABLE),
        -- Column('Version', 70,  0, Left,       'Version', LeftHeader,   not SORTABLE),
        Column('Author', 340, 16, Left,        'Author', nil,             SORTABLE),
        Column('Type',    60,  0, Library,            1, nil,             SORTABLE),
        -- Column('Group',  100,  0, Group,        'Group', CenterHeader,     SORTABLE),
        Column('Tags',   175,  0, Tags,          'Tags', RightHeader,     SORTABLE),
    }
    --]]

    local tooltip = {}
    local dependencyNames = {}

    local function addLine(line)
        tooltip[#tooltip+1] = line or ''
    end

    local function showTooltip(ctrl)
        ZO_ClearNumericallyIndexedTable(tooltip)
        ZO_ClearNumericallyIndexedTable(dependencyNames)

        local addonIndex = ctrl.dataEntry.data[1]
        local name, title, author, description, enabled, state, isOutOfDate, isLibrary = ADDON_MANAGER:GetAddOnInfo(addonIndex)

        local numDeps = ADDON_MANAGER:GetAddOnNumDependencies(addonIndex)

        local counterMissing, counterDisabled, counterOldVersion = 0, 0, 0
        for depIndex = 1, numDeps do
            local depName, exists, active, minVersion, version, depIsLibrary = ADDON_MANAGER:GetAddOnDependencyInfo(addonIndex, depIndex)

            if not exists then
                counterMissing = counterMissing + 1
            else
                if active then
                    if version < minVersion then
                        counterOldVersion = counterOldVersion + 1
                    end
                else
                    counterDisabled = counterDisabled + 1
                end
            end

            dependencyNames[#dependencyNames+1] = _formatAddonNameInTooltip(depName, exists, active, version, minVersion)
        end

        addLine(title)

        if author and author ~= '' then
            addLine('by '..author)
        end

        local addonVersion = DefaultAddOnManager:GetAddOnVersion(addonIndex)
        if addonVersion and addonVersion ~= 0 then
            addLine(('(Version: |cFFFFFF%d|r)'):format(addonVersion))
        else
            addLine('(Version: Unknown)')
        end

        -- addLine(name..'|'..title)
        -- addLine(STATE_NAMES[state])
        addLine()

        self.addonList[addonIndex].missing = counterMissing
        self.addonList[addonIndex].old = counterOldVersion

        if numDeps == 0 then
            addLine('No dependencies')
        else
            if #dependencyNames > 0 then
                addLine(('Dependencies (|cFFFFFF%d|r):'):format(NonContiguousCount(dependencyNames)))
                addLine(table.concat(dependencyNames, '\n'))
            end
        end

        if counterDisabled > 0 then
            addLine()
            -- TODO: correct way to make plural form?
            -- addLine(zo_strformat('Press to turn |c00FF00ON|r <<1>> |cFFFFFF<<2>>|r disabled <<m:3>>.', nil, counterDisabled, 'dependency'))
            addLine(('If you press the button, |cFFFFFF%d|r disabled dependencies will be turned |c00FF00ON|r.'):format(counterDisabled))
        end

        local dependentAddons = self.dependencies[name]
        if dependentAddons and next(dependentAddons) then
            addLine()
            addLine(('Dependent addons (|cFFFFFF%d|r):'):format(NonContiguousCount(dependentAddons)))
            for dependentAddonName in pairs(dependentAddons) do
                local dependentAddonIndex = self.nameToIndex[dependentAddonName]
                local _, _, _, _, dep_enabled = ADDON_MANAGER:GetAddOnInfo(dependentAddonIndex)

                addLine(_formatAddonNameInTooltip(dependentAddonName, true, dep_enabled, 1, 0))
                -- addLine(('- %s'):format(addonName))
            end
        end

        if counterMissing > 0 then
            addLine()
            addLine(('Install |cFFFFFF%d|r missing dependencies.'):format(counterMissing))
        end

        if counterOldVersion > 0 then
            addLine()
            addLine(('Update |cFFFFFF%d|r old dependencies.'):format(counterOldVersion))
        end

        ZO_Tooltips_ShowTextTooltip(ctrl, LEFT, table.concat(tooltip, '\n'))
    end

    local function showCustomMenu(row)
        ClearMenu()

        local addonIndex = row.dataEntry.data[1]
        local addonName = self.addonList[addonIndex][NAME]

        for tagIndex = 3, #self.tags do
            local tagName = self.tags[tagIndex]
            local text
            if self.addonTags[addonName][tagIndex] then
                text = ('Remove tag \'%s\''):format(tagName)
            else
                text = ('Add tag \'%s\''):format(tagName)
            end

            AddCustomMenuItem(text, function()
                if not self.addonTags[addonName] then
                    self.addonTags[addonName] = {}
                end
                self.addonTags[addonName][tagIndex] = not self.addonTags[addonName][tagIndex]

                self:Update()
            end)
        end

        if #self.tags - 2 == 0 then
            AddCustomMenuItem('Add more tags first!')
        end

        -- AddCustomMenuItem('Clear category', function()
        --     self.addonGroup[addonName] = nil
        --     self:Update()
        -- end)

        local dependentAddons = self.dependencies[addonName]
        if dependentAddons and next(dependentAddons) then
            AddCustomMenuItem('Turn off with dependants', function()
                ADDON_MANAGER:SetAddOnEnabled(addonIndex, false)
                for dependantAddonName in pairs(dependentAddons) do
                    local dependantAddonIndex = self.nameToIndex[dependantAddonName]
                    ADDON_MANAGER:SetAddOnEnabled(dependantAddonIndex, false)
                end
                self:Update()
            end)
        end

        ShowMenu(row)
    end

    local postCreateCallback = function(rowControl)
		rowControl:SetHandler('OnMouseEnter', showTooltip)
        rowControl:SetHandler('OnMouseExit', ZO_Tooltips_HideTextTooltip)

        rowControl:SetHandler('OnMouseDown', showCustomMenu)
	end
    local postSetupCallback = function(rowControl, dataEntryData, scrollList)
		rowControl:GetNamedChild('Index'):SetText(rowControl.index)
	end

    local WITH_HEADERS = true
    local myTable = Table(WITH_HEADERS)

    myTable:AddDataType(1, columns, 32, postCreateCallback, postSetupCallback)  -- dataType, list of columns, heigth
    myTable:SetMulticolumnSortingEnabled(true)
    myTable:SetDefaultSortingCriteria(
        5, ZO_SORT_ORDER_UP,
        2, ZO_SORT_ORDER_UP,
        3, ZO_SORT_ORDER_UP
    )

    local REPLACE = true
    local scrollControl = myTable:Create(self.listName, self.tlc, REPLACE)
    -- scrollControl:SetDimensions(600, 600)  -- now you can modify it as you want
    -- scrollControl:SetAnchor(CENTER)  -- and position

    self.scroll = myTable
end

local function _initializeFilter(control, entriesData, setFiltersCallback)
    local comboBox = ZO_ComboBox_ObjectFromContainer(control)

    comboBox:SetSortsItems(false)
    comboBox:SetFont('ZoFontWinT1')
    comboBox:SetSpacing(4)

    local function OnFilterChanged(comboBox_, entryText, entry)
        local newFilters = {}

        for i, itemData in ipairs(comboBox_.m_selectedItemData) do
            table.insert(newFilters, itemData.filterType)
        end

        setFiltersCallback(newFilters)

        df('Selection changed: %s', table.concat(comboBox_.m_selectedItemData, ','))
    end

    for i, entry in ipairs(entriesData) do
        local item = comboBox:CreateItemEntry(entry.text, OnFilterChanged)
        item.filterType = entry.type

        comboBox:AddItem(item)
    end

    return comboBox
end

function addon:InitializeGroupFilter()
    local filterControl = self.tlc:GetNamedChild('GroupFilter')
    self.groupFilterControl = filterControl

    local entriesData = {}

    for tagIndex, tagName in ipairs(self.tags) do
        table.insert(entriesData, {
            text = tagName,
            type = tagIndex,
        })
    end

    local function callback(newSelection)
        -- self.selections.modes = newSelection
        df('%s', table.concat(newSelection, ','))

        local temp = {}
        for i = 1, #newSelection do
            temp[newSelection[i]] = true
        end

        for i = 1, #self.tags do
            self.activeTags[i] = temp[i] or false  -- TODO: can do nil basically
        end

        self:Update()
    end

    local filter = _initializeFilter(filterControl, entriesData, callback)

    filter:SetNoSelectionText('|cFF0000Select Tags|r')
    filter:SetMultiSelectionTextFormatter('<<1[$d Tag/$d Tags]>> Selected')

    for tagIndex = 1, #self.tags do
        if self.activeTags[tagIndex] then
            filter:SelectItemByIndex(tagIndex, true)
            df('Selecting %d on initialization', tagIndex)
        end
    end

    -- local function SelectGroup(mode)
    --     for i, item in ipairs(filter.m_sortedItems) do
    --         if item.filterType == mode then
    --             filter:SelectItem(item, true)
    --             return
    --         end
    --     end
    -- end
    -- for _, mode in ipairs(self.selections.modes) do
    --     SelectGroup(mode)
    -- end
end

function addon:InitializeSearch()
    local function OnSearchTextChanged(editBox)
        local newText = string.lower(editBox:GetText())

        if newText == self.filters.searchText then return end

        self.filters.searchText = newText
        -- self.dirty = true
        self:Update()  -- TODO: throttling?
    end

    self.searchBox:SetDefaultText('Enter Addon or Author name')  -- TODO: i18n
    self.searchBox:SetHandler('OnTextChanged',  OnSearchTextChanged)

    self.searchBox:SetHandler('OnEffectivelyShown', function(self_) self_:TakeFocus() end)
end

function addon:Update()
    local data = {}

    local searchText = self.filters.searchText

    local function addAddon(index)
        local addonData = self.addonList[index]
        local name, title, author, description, enabled, state, isOutOfDate, isLibrary = ADDON_MANAGER:GetAddOnInfo(index)

        -- local ltitle = string.lower(title)

        -- df('Title: %s, serachText: %s, found: %s', title, searchText, tostring(string.find(ltitle, searchText)))

        local thisAddonTags = self.addonTags[name]
        local shouldShow = false
        for tagIndex = 1, #self.tags do
            local tagActive = self.activeTags[tagIndex]
            if tagActive and thisAddonTags[tagIndex] then
                shouldShow = true
                break
            end
        end

        if not shouldShow then return end

        if searchText then
            if not string.find(addonData.searchText, searchText) then
                return
            end
        end

        data[#data+1] = {
            index,
            __getState(enabled, state),
            addonData.clearTitle,
            -- addonData.version,
            author,  -- TODO: can save to addonData data which will never change to avoid calls
            isLibrary and 1 or 0,
            -- self.groups[addonGroupId].priority,
            'здесь будут теги',
        }

        --[[
        data[#data+1] = {
            index,
            __getState(addonData[ENABLED], addonData[STATE]),
            addonData[TITLE],  -- TODO: pass title without colors, but replace afterwards
            addonData[AUTHOR],
            addonData[IS_LIBRARY] and 1 or 0,
            addonData[NUM_DEPENDENCIES],
        }
        ]]
    end

    for a = 1, #self.addonList do
        addAddon(a)
    end

    self.scroll:Update(1, data)
end

function addon:CheckIfDependencyInUse(dependencyName)
    local usedBy = {}
    local addonsUsingIt = self.dependencies[dependencyName]

    for addonName in pairs(addonsUsingIt) do
        local addonIndex = self.nameToIndex[addonName]
        local name, title, author, description, enabled, state, isOutOfDate, isLibrary = ADDON_MANAGER:GetAddOnInfo(addonIndex)
        if enabled then
            usedBy[#usedBy+1] = name
            -- df('%d dependency of %s (%s) is used by %s. Can`t turn off.', depIndex, name_, depName, name)
        end
    end

    df('%s used by %d addons (%s)', dependencyName, #usedBy, table.concat(usedBy, ', '))

    return #usedBy > 0
end

function addon:CheckIfLibrariesCanBeTurnedOff(addonIndex)
    local name_ = ADDON_MANAGER:GetAddOnInfo(addonIndex)
    df('Addon: %s', name_)

    local numDeps = ADDON_MANAGER:GetAddOnNumDependencies(addonIndex)
    for depIndex = 1, numDeps do
        local depName, exists, active, minVersion, version, depIsLibrary = ADDON_MANAGER:GetAddOnDependencyInfo(addonIndex, depIndex)
        local inUse = self:CheckIfDependencyInUse(depName)

        if depIsLibrary and not inUse then
            local dependencyAddonIndex = self.nameToIndex[depName]
            ADDON_MANAGER:SetAddOnEnabled(dependencyAddonIndex, false)
            df('%s is not in use, can turn off.', depName)
        else
            df('%s is in use, can\'t turn off.', depName)
        end
    end

    -- self:Update()
end

function addon:CheckIfLibrariesShouldBeTurnedOn(addonIndex)
    local addonName = ADDON_MANAGER:GetAddOnInfo(addonIndex)
    df('Addon: %s', addonName)

    local numDeps = ADDON_MANAGER:GetAddOnNumDependencies(addonIndex)
    for depIndex = 1, numDeps do
        local depName, exists, active, minVersion, version, depIsLibrary = ADDON_MANAGER:GetAddOnDependencyInfo(addonIndex, depIndex)
        -- if addonName ~= depName then
        local dependencyAddonIndex = self.nameToIndex[depName]
        if not active then
            ADDON_MANAGER:SetAddOnEnabled(dependencyAddonIndex, true)
            df('%s turned on', depName)
        else
            df('%s is already active', depName)
        end

        if not self.changes[dependencyAddonIndex] then
            self.changes[dependencyAddonIndex] = {
                initial = self.addonList[dependencyAddonIndex].initial
            }
        end
        self.changes[dependencyAddonIndex].new = active
        -- end
    end

    -- self:Update()
end

-- esoui\pregameandingame\addons\gamepad\zo_addonmanager_gamepad.lua, line 781
local function StripText(text)
    return text:gsub('|c%x%x%x%x%x%x', '')
end

function addon:GetNumChanges()
    local counter = 0

    for addonIndex, state in pairs(self.changes) do
        if state.initial ~= state.new then
            counter = counter + 1
        end
    end

    return counter
end

local DEFAULTS = {
    groups = {
        {name = 'Default', priority = 999,},
        {name = 'Vital',   priority = 0,},
        {name = 'Med',     priority = 300,},
        {name = 'Low',     priority = 600,},
    },
    addonGroup = {

    },
    tags = {
        'addon',
        'lib',
    },
    addonTags = {},
    activeTags = {true, true},
}

function addon:Initialize()
    self.awsv = ZO_SavedVars:NewAccountWide('ImprovedAddonsListSV', 1, nil, DEFAULTS)
    self.chsv = ZO_SavedVars:New('ImprovedAddonsListSV', 1, nil, DEFAULTS)

    self.groups = self.awsv.groups

    self.tags = self.chsv.tags
    self.addonTags = self.chsv.addonTags
    self.activeTags = self.chsv.activeTags
    self.addonGroup = self.awsv.addonGroup

    local addonList = {}
    local dependencies = {}
    local nameToIndex = {}

    local numAddons = ADDON_MANAGER:GetNumAddOns()
    for addonIndex = 1, numAddons do
        local name, title, author, description, enabled, state, isOutOfDate, isLibrary = ADDON_MANAGER:GetAddOnInfo(addonIndex)

        self.addonTags[name] = {}
        if isLibrary then
            self.addonTags[name][2] = true
        else
            self.addonTags[name][1] = true
        end

        -- local addonGroupId = self.addonGroup[name] or 1
        local addonData = {
            [NAME] = name,
            [TITLE] = title,
            searchText = string.lower(('%s|%s|%s'):format(name, title, author)),  -- TODO: description?,
            clearTitle = StripText(title),
            initial = enabled,
            version = ADDON_MANAGER:GetAddOnVersion(addonIndex),
            -- groupId = addonGroupId,
        }

        addonList[addonIndex] = addonData

        local numDeps = ADDON_MANAGER:GetAddOnNumDependencies(addonIndex)
        for depIndex = 1, numDeps do
            local depName, exists, active, minVersion, version, depIsLibrary = ADDON_MANAGER:GetAddOnDependencyInfo(addonIndex, depIndex)
            if not dependencies[depName] then
                dependencies[depName] = {}
            end
            dependencies[depName][name] = true
        end

        nameToIndex[name] = addonIndex
    end
    self.addonList = addonList
    self.dependencies = dependencies
    self.nameToIndex = nameToIndex

    self.changes = {}
    ZO_PostHook(ADDON_MANAGER, 'SetAddOnEnabled', function(am, addonIndex, enabled)
        if not self.changes[addonIndex] then
            self.changes[addonIndex] = {
                initial = self.addonList[addonIndex].initial,
            }
        end
        self.changes[addonIndex].new = enabled

        df('Num total changes: %d', self:GetNumChanges())
    end)

    self.tlc = IMP_ImprovedAddonList
    self.listName = 'ScrollList'
    self:CreateTable()

    self.searchBox = self.tlc:GetNamedChild('SearchContainerSearchBox')
    self.filters = {}
    self:InitializeSearch()

    self.switchButton = self.tlc:GetNamedChild('TurnAllOff')
    self:SetButtonState(not self:GetNotWhitelistAddonsActive())

    self:InitializeGroupFilter()

    self:ReplaceMainMenuEntry()

    self:Update()

    self:RefreshKeybinds()
end

function addon:ReplaceMainMenuEntry()
    IMPROVED_ADDONS_FRAGMENT = ZO_FadeSceneFragment:New(self.tlc)
    IMPROVED_ADDONS_FRAGMENT:RegisterCallback('StateChange', function(oldState, newState)
        if newState == SCENE_FRAGMENT_SHOWING then
            PushActionLayerByName('Addons')
        elseif newState == SCENE_FRAGMENT_HIDING then
            RemoveActionLayerByName('Addons')
        end
    end)

    ZO_PreHook(SCENE_MANAGER, 'AddFragment', function(sceneManager, fragment)
        if fragment == ADDONS_FRAGMENT then
            SCENE_MANAGER:AddFragment(IMPROVED_ADDONS_FRAGMENT)
            return true
        end
    end)

    ZO_PreHook(SCENE_MANAGER, 'RemoveFragment', function(sceneManager, fragment)
        if fragment == ADDONS_FRAGMENT then
            SCENE_MANAGER:RemoveFragment(IMPROVED_ADDONS_FRAGMENT)
            return true
        end
    end)
end

-- adopted from esoui\pregameandingame\addons\zo_addonmanager.lua
function addon:RefreshKeybinds()
    local primaryKeybindDescriptor =
    {
        keybind = 'ADDONS_PANEL_PRIMARY',
        name = function()
            if HasAgreedToEULA(EULA_TYPE_ADDON_EULA) then
                return ('%s (%d changes total)'):format(GetString(SI_ADDON_MANAGER_RELOAD), self:GetNumChanges())
            else
                return GetString(SI_ADDON_MANAGER_VIEW_EULA)
            end
        end,
        enabled = function()
            if HasAgreedToEULA(EULA_TYPE_ADDON_EULA) then
                return self:GetNumChanges() > 0
            end

            return true
        end,
        callback = function()
            if HasAgreedToEULA(EULA_TYPE_ADDON_EULA) then
                ReloadUI('ingame')
            else
                CALLBACK_MANAGER:FireCallbacks('ShowAddOnEULAIfNecessary')
            end
        end,
    }

    local primaryButton = self.tlc:GetNamedChild('PrimaryButton')
    primaryButton:SetKeybindButtonDescriptor(primaryKeybindDescriptor)

    self:UpdateKeybindButton(primaryButton, primaryKeybindDescriptor)

    -- self:RefreshSavedKeybindsLabel()
end

-- adopted from esoui\pregameandingame\addons\zo_addonmanager.lua
function addon:UpdateKeybindButton(keybindButton, descriptor)
    local visible = descriptor.visible or true
    if type(visible) == 'function' then
        visible = visible()
    end

    keybindButton:SetHidden(not visible)

    local enabled = descriptor.enabled or true
    if type(enabled) == 'function' then
        enabled = enabled()
    end

    keybindButton:SetEnabled(enabled)
end

local WHITESLIST = {
    ['ImprovedAddonList'] = true,
    ['LibScrollList'] = true,
    ['LibCustomMenu'] = true,
}
function addon:SwitchAddonsState()
    local addonsNotFromWhiteListEnabled = false

    local numAddons = ADDON_MANAGER:GetNumAddOns()
    for addonIndex = 1, numAddons do
        local name, title, author, description, enabled, state, isOutOfDate, isLibrary = ADDON_MANAGER:GetAddOnInfo(addonIndex)
        if enabled then
            if not WHITESLIST[name] then
                ADDON_MANAGER:SetAddOnEnabled(addonIndex, false)
                addonsNotFromWhiteListEnabled = true
            end
        end
    end

    if not addonsNotFromWhiteListEnabled then
        for addonIndex = 1, numAddons do
            ADDON_MANAGER:SetAddOnEnabled(addonIndex, true)
        end
    end

    self:SetButtonState(addonsNotFromWhiteListEnabled)

    self:Update()
end

function addon:SetButtonState(allOff)
    if allOff then
        self.switchButton:SetText('Global ON')
    else
        self.switchButton:SetText('Global OFF')
    end
end

-- TODO: optimize, check on load instead
function addon:GetNotWhitelistAddonsActive()
    local numAddons = ADDON_MANAGER:GetNumAddOns()
    for addonIndex = 1, numAddons do
        local name, title, author, description, enabled, state, isOutOfDate, isLibrary = ADDON_MANAGER:GetAddOnInfo(addonIndex)
        if enabled then
            if not WHITESLIST[name] then
                return true
            end
        end
    end

    return false
end


local function OnAddonLoaded(_, addonName)
    if addonName ~= addon.name then return end
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_ADD_ON_LOADED)

    addon:Initialize()

    IMP_GLOBAL_TEST = addon
end

EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_ADD_ON_LOADED, OnAddonLoaded)

function IMP_ImprovedAddonList_SwitchAddonsState()
    addon:SwitchAddonsState()
end
-- TODO: dirty