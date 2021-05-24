--[[orderListBoxData = {
    type = "orderlistbox",
    name = "My OrderListBox", -- or string id or function returning a string
    listEntries = {
        [1] = {
            value = "Value of the entry", -- or number or boolean or function returning the value of this entry
            uniqueKey = 1, --number of the unique key of this list entry. This will not change if the order changes. Will be used to identify the entry uniquely
            text  = "Text of this entry", -- or string id or function returning a string (optional)
            tooltip = "Tooltip text shown at this entry", -- or string id or function returning a string (optional)
        },
        [2] = {...},
        ...
    },
    disableDrag = false, -- or function returning a boolean (optional). Disable the drag&drop of the rows
    disableButtons = false, -- or function returning a boolean (optional). Disable the move up/move down/move to top/move to bottom buttons
    showPosition = false, -- or function returning a boolean (optional). Show the position number in front of the list entry
    getFunc = function() return db.currentSortedListEntries end,
    setFunc = function(currentSortedListEntries) db.currentSortedListEntries = currentSortedListEntries doStuff() end,
    tooltip = "OrderListBox's tooltip text.", -- or string id or function returning a string (optional)
    width = "full", -- or "half" (optional)
    isExtraWide = false, -- or function returning a boolean (optional). Show the listBox as extra wide box
    minHeight = function() return db.minHeightNumber end, --or number for the minimum height of this control. Default: 125 (optional)
    maxHeight = function() return db.maxHeightNumber end, --or number for the maximum height of this control. Default: value of minHeight (optional)
    rowHeight = function() return db.rowHeightNumber end, --or number for the height of the row of the entries in listEntries. Default: 25 (optional)
    rowTemplate = "LAM2_orderlistbox_widget_scrolllist_row", --String defining the XML virtual template control for a row of the listEntries (optional)
    rowFont = "ZoFontWinH4", --or function returning a String of the font to use for the row (optional),
    rowMaxLineCount = 1, --or function returning a number of the maximum text lines within the row. 1 = Only 1 text line, no wrapping, get#s truncated. (optional)
    rowSelectionTemplate = "ZO_ThinListHighlight", --String defining the XML virtual template control for the selection at a row of the listEntries (optional)
    rowSelectedCallback = function doStuffOnSelection(rowControl, previouslySelectedData, selectedData, reselectingDuringRebuild) end, --An optional callback function when a row of the listEntries got selected (optional)
    rowHideCallback = function doStuffOnHide(rowControl, currentRowData) end, --An optional callback function when a row of the listEntries got hidden (optional)
    dataTypeSelectSound = SOUNDS["NONE"], --or function returning a String of a sound from the global SOUNDS table. Will be played as any row containing the datatype (1) of the orderListBox will be selected (optional)
    dataTypeResetControlCallback = function doStuffOnReset(control) end, --An optional callback function when the datatype control gets reset. (optional)
    disabled = function() return db.someBooleanSetting end, -- or boolean (optional)
    warning = "May cause permanent awesomeness.", -- or string id or function returning a string (optional)
    requiresReload = false, -- boolean, if set to true, the warning text will contain a notice that changes are only applied after an UI reload and any change to the value will make the "Apply Settings" button appear on the panel which will reload the UI when pressed (optional)
    default = defaults.var, -- default value or function that returns the default value (optional)
    helpUrl = "https://www.esoui.com/portal.php?id=218&a=faq", -- a string URL or a function that returns the string URL (optional)
    reference = "MyAddonOrderListBox" -- unique global reference to control (optional)
} ]]

local widgetVersion = 6
local LAM = LibAddonMenu2
local util = LAM.util
local em = EVENT_MANAGER
local wm = WINDOW_MANAGER
local cm = CALLBACK_MANAGER

local LAMgetDefaultValue = util.GetDefaultValue

--Translations
local moveText = GetString(SI_HOUSINGEDITORCOMMANDTYPE1)
local moveTextLower = string.lower(moveText)
local translations = {
    ["en"] = {
        UP              = moveText .. " up",
        DOWN            = moveText .. " down",
        TOTAL_UP        = moveText .. " to top",
        TOTAL_DOWN      = moveText .. " to bottom",
    },
    ["de"] = {
        UP              = "Hoch " .. moveTextLower,
        DOWN            = "Herrunter " .. moveTextLower,
        TOTAL_UP        = "Zum Anfang " .. moveTextLower,
        TOTAL_DOWN      = "Zum Ende " .. moveTextLower,
    },
    ["jp"] = {
        UP              = moveText .. " 上",
        DOWN            = moveText .. " 下へ",
        TOTAL_UP        = moveText .. " 頂点に",
        TOTAL_DOWN      = moveText .. " 一番下に",
    },
    ["fr"] = {
        UP              = moveText .. " en haut",
        DOWN            = moveText .. " en bas",
        TOTAL_UP        = moveText .. " jusqu'au sommet",
        TOTAL_DOWN      = moveText .. " vers le bas",
    },
    ["ru"] = {
        UP              = moveText .. " вверх",
        DOWN            = moveText .. " вниз",
        TOTAL_UP        = moveText .. " наверх",
        TOTAL_DOWN      = moveText .. " ко дну",
    },
}
local lang = string.lower(GetCVar("Language.2"))
local translation = (translations[lang] ~= nil and translations[lang]) or translations["en"]

--Event handler constants
local EVENT_HANDLER_NAMESPACE = "LAM2_OrderListBox_Event"

--Constants visuals
local LAM_SORT_LIST_BOX_SCROLL_LIST_DATATYPE = 1

local SORT_LIST_ROW_DEFAULT_HEIGHT          = 25
local SORT_LIST_ROW_DEFAULT_FONT            = "ZoFontWinH4"
local SORT_LIST_ROW_DEFAULT_MAXLINES        = 1
local SORT_LIST_ROW_TEMPLATE_NAME           = "LAM2_orderlistbox_widget_scrolllist_row" --"ZO_SelectableLabel"
local SORT_LIST_ROW_SELECTION_TEMPLATE_NAME = "ZO_ThinListHighlight"

local MIN_HEIGHT                            = SORT_LIST_ROW_DEFAULT_HEIGHT * 5

local cursorTLC
local cursorTLCLabel

------------------------------------------------------------------------------------------------------------------------
--Local helper functions
------------------------------------------------------------------------------------------------------------------------
--Functions of the cursor UI related TLC
local function getCursorTLC()
    cursorTLC = wm:GetControlByName("LAM2_orderlistbox_widget_cursor_TLC", nil)
    if not cursorTLC then return end
    cursorTLCLabel = GetControl(cursorTLC, "Label")
    cursorTLC:ClearAnchors()
    cursorTLC:SetDimensions(0, 0)
end

--Functions of the listBox data table
local function getShowPositionInfoFromListBoxData(orderListBoxData)
    local showPosition = (orderListBoxData.showPosition ~= nil and LAMgetDefaultValue(orderListBoxData.showPosition)) or false
    return showPosition
end

local function getRowInfoFromOrderListBoxData(orderListBoxData)
    local rowHeight = (orderListBoxData.rowHeight and LAMgetDefaultValue(orderListBoxData.rowHeight)) or SORT_LIST_ROW_DEFAULT_HEIGHT
    local rowTemplate = (orderListBoxData.rowTemplate and LAMgetDefaultValue(orderListBoxData.rowTemplate)) or SORT_LIST_ROW_TEMPLATE_NAME
    local rowFont = (orderListBoxData.rowFont and LAMgetDefaultValue(orderListBoxData.rowFont)) or SORT_LIST_ROW_DEFAULT_FONT
    local rowMaxLineCount = (orderListBoxData.rowMaxLineCount and LAMgetDefaultValue(orderListBoxData.rowMaxLineCount)) or SORT_LIST_ROW_DEFAULT_MAXLINES
    local rowSelectionTemplate = (orderListBoxData.rowSelectionTemplate and LAMgetDefaultValue(orderListBoxData.rowSelectionTemplate)) or SORT_LIST_ROW_SELECTION_TEMPLATE_NAME
    local rowSelectedCallback = (orderListBoxData.rowSelectedCallback and LAMgetDefaultValue(orderListBoxData.rowSelectedCallback)) or nil
    local dataTypeSelectSound = (orderListBoxData.dataTypeSelectSound and LAMgetDefaultValue(orderListBoxData.dataTypeSelectSound)) or nil
    local rowHideCallback = (orderListBoxData.rowHideCallback and LAMgetDefaultValue(orderListBoxData.rowHideCallback)) or nil
    local dataTypeResetControlCallback = (orderListBoxData.dataTypeResetControlCallback and LAMgetDefaultValue(orderListBoxData.dataTypeResetControlCallback)) or nil
    return rowHeight, rowTemplate, rowFont, rowMaxLineCount, rowSelectionTemplate, rowSelectedCallback, rowHideCallback, dataTypeSelectSound, dataTypeResetControlCallback
end

local function getDisabledInfoFromListBoxData(orderListBoxData)
    local disabledDrag      = (orderListBoxData.disableDrag and LAMgetDefaultValue(orderListBoxData.disableDrag)) or false
    local disableButtons    = (orderListBoxData.disableButtons and LAMgetDefaultValue(orderListBoxData.disableButtons)) or false
    return disabledDrag, disableButtons
end

--Update & disabled
local function updateButtonsEnabledState(control, areButtonsDisabled, orderListBoxData, buttonMoveUpControl, buttonMoveDownControl, buttonMoveTotalUpControl, buttonMoveTotalDownControl)
    if not control then return end
    if orderListBoxData == nil or buttonMoveUpControl == nil or buttonMoveDownControl  == nil or buttonMoveTotalUpControl  == nil or buttonMoveTotalDownControl == nil then
        local orderListBox  = control.orderListBox
        orderListBoxData = orderListBox.orderListBoxData
        buttonMoveUpControl, buttonMoveDownControl, buttonMoveTotalUpControl, buttonMoveTotalDownControl = orderListBox.moveUpButton, orderListBox.moveDownButton, orderListBox.moveTotalUpButton, orderListBox.moveTotalDownButton
    end
    if areButtonsDisabled == nil then
        areButtonsDisabled = orderListBoxData ~= nil and select(2, getDisabledInfoFromListBoxData(orderListBoxData))
    end
    if areButtonsDisabled == nil then areButtonsDisabled = false end
    local mouseEnabled = not areButtonsDisabled

    buttonMoveUpControl:SetHidden(areButtonsDisabled)
    buttonMoveUpControl:SetMouseEnabled(mouseEnabled)
    buttonMoveDownControl:SetHidden(areButtonsDisabled)
    buttonMoveDownControl:SetMouseEnabled(mouseEnabled)
    buttonMoveTotalUpControl:SetHidden(areButtonsDisabled)
    buttonMoveTotalUpControl:SetMouseEnabled(mouseEnabled)
    buttonMoveTotalDownControl:SetHidden(areButtonsDisabled)
    buttonMoveTotalDownControl:SetMouseEnabled(mouseEnabled)
end

local function updateOrderListBoxEntries(control, value)
    --d("updateOrderListBoxEntries")
    local orderListBox = control.orderListBox
    orderListBox.orderListBoxData.listEntries = value
    --Update the order list now with new populated masterlist
    orderListBox.masterList = orderListBox:Populate(orderListBox.orderListBoxData)
    orderListBox:UpdateScrollList(orderListBox.scrollListControl, orderListBox.masterList, LAM_SORT_LIST_BOX_SCROLL_LIST_DATATYPE, orderListBox)
end

local function updateDisabledStateOfControls(control, disable)
    local enabledState = not disable
    control:SetMouseEnabled(enabledState)
    local orderListBox  = control.orderListBox
    local scrollList    = control.orderListBox.scrollListControl

    scrollList:SetMouseEnabled(enabledState)

    orderListBox.disabled = disable
    local areButtonsDisabled = disable
    --Hide the buttons as no entry was selected, as we currently are building the LAM controls.
    --Or after re-enabling the LAM control again via the UpdateDisabled function and no entry is selected.
    if areButtonsDisabled == false and (control.isBuilding == true or (scrollList and scrollList.selectedDataIndex == nil)) then
        areButtonsDisabled = true
    elseif areButtonsDisabled == false then
        areButtonsDisabled = orderListBox.areButtonsDisabled
    end
    updateButtonsEnabledState(control, areButtonsDisabled, orderListBox.orderListBoxData, orderListBox.moveUpButton, orderListBox.moveDownButton, orderListBox.moveTotalUpButton, orderListBox.moveTotalDownButton)

    --Disable scrollbar
    ZO_ScrollList_SetUseScrollbar(scrollList, enabledState)
    --Redraw the scrolllist
    ZO_ScrollList_Commit(scrollList)
end

--Drag & drop functions
local function clearDragging(selfVar)
    selfVar.draggingEntryId = nil
    selfVar.draggingSortListContents = nil
    selfVar.draggingText = nil
    selfVar.draggingUpdateTime = nil
    selfVar.mouseButtonPressed = nil
end

local function disableOnUpdateHandlerAndResetMouseCursor(orderListBoxObject)
    em:UnregisterForEvent(EVENT_HANDLER_NAMESPACE .. "_GLOBAL_MOUSE_DOWN", EVENT_GLOBAL_MOUSE_DOWN)
    em:UnregisterForEvent(EVENT_HANDLER_NAMESPACE .. "_GLOBAL_MOUSE_UP", EVENT_GLOBAL_MOUSE_UP)
    orderListBoxObject.scrollListControl:SetHandler("OnUpdate", nil)

    --Hide the label control at the cursor again
    orderListBoxObject:UpdateCursorTLC(true, nil)
end

local function abortDragging(orderListBoxObject)
    disableOnUpdateHandlerAndResetMouseCursor(orderListBoxObject)
    clearDragging(orderListBoxObject)
end

local function checkIfDraggedAndDisableUpdateHandler(lamPanel)
    if cursorTLC == nil then getCursorTLC() end
    if not cursorTLC then return end
    local orderListBoxObject = cursorTLC.orderListBox
    if orderListBoxObject == nil or orderListBoxObject.draggingEntryId == nil then return end
    abortDragging(orderListBoxObject)
    wm:SetMouseCursor(MOUSE_CURSOR_DO_NOT_CARE)
end


local function UpdateDisabled(control)
    local dataDisabled = control.data.disabled
    local disable = (dataDisabled ~= nil and LAMgetDefaultValue(dataDisabled)) or false
    if disable then
        control.label:SetColor(ZO_DEFAULT_DISABLED_COLOR:UnpackRGBA())
    else
        control.label:SetColor(ZO_DEFAULT_ENABLED_COLOR:UnpackRGBA())
    end
    local orderListBox = control.orderListBox
    abortDragging(orderListBox)

    updateDisabledStateOfControls(control, disable)
end

local function UpdateValue(control, forceDefault, value)
--d(">UpdateValue - value: " ..tostring(value))
    local requestRefresh = false
    if forceDefault then --if we are forcing defaults
        value = LAMgetDefaultValue(control.data.default)
        control.data.setFunc(value)
    elseif value then
        control.data.setFunc(value)
        requestRefresh = true
    else
        value = control.data.getFunc()
    end
    updateOrderListBoxEntries(control, value)
    if requestRefresh == true then
        --after setting this value, let's refresh the others to see if any should be disabled or have their settings changed
        util.RequestRefreshIfNeeded(control)
    end
end

------------------------------------------------------------------------------------------------------------------------
--OrderListBox class
------------------------------------------------------------------------------------------------------------------------
local OrderListBox = ZO_Object:Subclass()

function OrderListBox:New(...)
    local object = ZO_Object.New(self)
    object:Initialize(...)
    return object
end


function OrderListBox:Initialize(panel, control, orderListBoxData)
    local combobox = control.combobox
    --local selfVar = self
    self.panel = panel
    self.control = control

    self.orderListBoxData = orderListBoxData

    --Attributes of the orderListBoxData -> Set default values
    -->Will be updated within self:Create() function (from orderListBoxData)
    self.disabled = false
    self.areButtonsDisabled = false
    self.isDragDisabled = false
    self.showPosition = false
    self.rowHeight = SORT_LIST_ROW_DEFAULT_HEIGHT
    self.rowTemplate = SORT_LIST_ROW_TEMPLATE_NAME
    self.rowFont = SORT_LIST_ROW_DEFAULT_FONT
    self.rowMaxLineCount = SORT_LIST_ROW_DEFAULT_MAXLINES
    self.rowSelectionTemplate = SORT_LIST_ROW_SELECTION_TEMPLATE_NAME
    self.rowSelectedCallback = nil
    self.rowHideCallback = nil
    self.dataTypeSelectSound = nil
    self.dataTypeResetControlCallback = nil

    --Create the ZO_ScrollList with the move up and down buttons
    self.scrollListControl, self.moveUpButton, self.moveDownButton, self.moveTotalUpButton, self.moveTotalDownButton = self:Create(control, orderListBoxData)
end

--Create the scroll list and it's dataType, set the init values etc. Control is the LAM "container" containing the ZO_ScrollList we create here
function OrderListBox:Create(control, orderListBoxData)
    --d("[LAM2]OrderListBox:Create")
    local selfVar = self
    local controlContainer = control.container
    local controlName = control:GetName()

    --OrderListBox -> ZO_ScrollList control
    local scrollListControl = wm:CreateControlFromVirtual(controlName .. "_OrderListBox", control, "ZO_ScrollList")
    local controlHeight = control:GetHeight()
    local widthXMinus = (orderListBoxData.width=="half" and 16) or 12
    local width = controlContainer:GetWidth() - widthXMinus
    scrollListControl:SetDimensions(width, controlHeight)
    scrollListControl:SetAnchor(TOPLEFT, controlContainer, TOPLEFT)
    scrollListControl:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, (widthXMinus * -1), 0)
    scrollListControl:SetHidden(false)

    --Add the move up and move down button controls at the right of the ZO_ScrollList
    local function onButtonClicked(buttonCtrl, mouseButton, ctrl, alt, shift, command, isUp, moveToTopOrBottom)
        --d(">Clicked - isUp: " ..tostring(isUp))
        --Left mouse clicked?
        if mouseButton ~= MOUSE_BUTTON_INDEX_LEFT then return end
        --Is any item selected?
        local selectedEntry = ZO_ScrollList_GetSelectedData(scrollListControl)
        if selectedEntry == nil then return end
        local selectedIndex = ZO_ScrollList_GetSelectedDataIndex(scrollListControl)
        --Move up or down button clicked
        if isUp then
            --Is the selected entry the most top entry already?
            if selectedIndex == 1 then return end
        else
            --Is the selected entry the most bottom entry already?
            if selectedIndex == #scrollListControl.data then return end
        end
        selfVar:MoveItem(selectedIndex, isUp, nil, moveToTopOrBottom)
    end

    local buttonMoveUpControl = wm:CreateControl(controlName .. "_ButtonMoveUp", scrollListControl, CT_BUTTON)
    buttonMoveUpControl:SetDimensions(16, 16)
    buttonMoveUpControl:SetNormalTexture("/esoui/art/buttons/scrollbox_uparrow_up.dds")
    buttonMoveUpControl:SetMouseOverTexture("/esoui/art/buttons/scrollbox_uparrow_over.dds")
    buttonMoveUpControl:SetPressedMouseOverTexture("/esoui/art/buttons/scrollbox_uparrow_down.dds")
    buttonMoveUpControl:SetPressedTexture("/esoui/art/buttons/scrollbox_uparrow_down.dds")
    buttonMoveUpControl:SetDisabledTexture("/esoui/art/buttons/scrollbox_uparrow_up_disabled.dds")
    buttonMoveUpControl:SetPressedOffset(2, 2)
    buttonMoveUpControl:SetAnchor(LEFT, scrollListControl, RIGHT, 0, -16)
    buttonMoveUpControl:SetHidden(true)
    buttonMoveUpControl:SetClickSound("Click")
    buttonMoveUpControl.data = {tooltipText = util.GetStringFromValue(translations[lang].UP)}
    buttonMoveUpControl:SetHandler("OnMouseEnter", function(button)
        if selfVar.disabled then return end
        ZO_Options_OnMouseEnter(button)
        wm:SetMouseCursor(MOUSE_CURSOR_UI_HAND)
    end)
    buttonMoveUpControl:SetHandler("OnMouseExit", function(button)
        if selfVar.disabled then return end
        ZO_Options_OnMouseExit(button)
        wm:SetMouseCursor(MOUSE_CURSOR_DO_NOT_CARE)
    end)
    buttonMoveUpControl:SetHandler("OnClicked", function(buttonCtrl, button, ctrl, alt, shift, command)
        if selfVar.disabled then return end
        onButtonClicked(buttonCtrl, button, ctrl, alt, shift, command, true, false)
    end)
    buttonMoveUpControl:SetMouseEnabled(false)

    local buttonMoveDownControl = wm:CreateControl(controlName .. "_ButtonMoveDown", scrollListControl, CT_BUTTON)
    buttonMoveDownControl:SetDimensions(16, 16)
    buttonMoveDownControl:SetNormalTexture("/esoui/art/buttons/scrollbox_downarrow_up.dds")
    buttonMoveDownControl:SetMouseOverTexture("/esoui/art/buttons/scrollbox_downarrow_over.dds")
    buttonMoveDownControl:SetPressedMouseOverTexture("/esoui/art/buttons/scrollbox_downarrow_down.dds")
    buttonMoveDownControl:SetPressedTexture("/esoui/art/buttons/scrollbox_downarrow_down.dds")
    buttonMoveDownControl:SetDisabledTexture("/esoui/art/buttons/scrollbox_downarrow_up_disabled.dds")
    buttonMoveDownControl:SetPressedOffset(2, 2)
    buttonMoveDownControl:SetAnchor(LEFT, scrollListControl, RIGHT, 0, 12)
    buttonMoveDownControl:SetHidden(true)
    buttonMoveDownControl:SetClickSound("Click")
    buttonMoveDownControl.data = {tooltipText = util.GetStringFromValue(translations[lang].DOWN)}
    buttonMoveDownControl:SetHandler("OnMouseEnter", function(button)
        if selfVar.disabled then return end
        ZO_Options_OnMouseEnter(button)
        wm:SetMouseCursor(MOUSE_CURSOR_UI_HAND)
    end)
    buttonMoveDownControl:SetHandler("OnMouseExit", function(button)
        if selfVar.disabled then return end
        ZO_Options_OnMouseExit(button)
        wm:SetMouseCursor(MOUSE_CURSOR_DO_NOT_CARE)
    end)
    buttonMoveDownControl:SetHandler("OnClicked", function(buttonCtrl, button, ctrl, alt, shift, command)
        if selfVar.disabled then return end
        onButtonClicked(buttonCtrl, button, ctrl, alt, shift, command, false, false)
    end)
    buttonMoveDownControl:SetMouseEnabled(false)

    local buttonMoveTotalUpControl = wm:CreateControl(controlName .. "_ButtonMoveTotalUp", scrollListControl, CT_BUTTON)
    buttonMoveTotalUpControl:SetDimensions(16, 16)
    buttonMoveTotalUpControl:SetNormalTexture("/esoui/art/chatwindow/chat_scrollbar_endarrow_up.dds")
    buttonMoveTotalUpControl:SetMouseOverTexture("/esoui/art/chatwindow/chat_scrollbar_endarrow_over.dds")
    buttonMoveTotalUpControl:SetPressedMouseOverTexture("/esoui/art/chatwindow/chat_scrollbar_endarrow_down.dds")
    buttonMoveTotalUpControl:SetPressedTexture("/esoui/art/chatwindow/chat_scrollbar_endarrow_down.dds")
    buttonMoveTotalUpControl:SetDisabledTexture("/esoui/art/chatwindow/chat_scrollbar_endarrow_disabled.dds")
    buttonMoveTotalUpControl:SetPressedOffset(2, 2)
    buttonMoveTotalUpControl:SetTextureCoords(1, 0, 1, 0) -- rotate by 180° so the texture points up
    buttonMoveTotalUpControl:SetAnchor(BOTTOM, buttonMoveUpControl, TOP, 0, -4)
    buttonMoveTotalUpControl:SetHidden(true)
    buttonMoveTotalUpControl:SetClickSound("Click")
    buttonMoveTotalUpControl.data = {tooltipText = util.GetStringFromValue(translations[lang].TOTAL_UP)}
    buttonMoveTotalUpControl:SetHandler("OnMouseEnter", function(button)
        if selfVar.disabled then return end
        ZO_Options_OnMouseEnter(button)
        wm:SetMouseCursor(MOUSE_CURSOR_UI_HAND)
    end)
    buttonMoveTotalUpControl:SetHandler("OnMouseExit", function(button)
        if selfVar.disabled then return end
        ZO_Options_OnMouseExit(button)
        wm:SetMouseCursor(MOUSE_CURSOR_DO_NOT_CARE)
    end)
    buttonMoveTotalUpControl:SetHandler("OnClicked", function(buttonCtrl, button, ctrl, alt, shift, command)
        if selfVar.disabled then return end
        onButtonClicked(buttonCtrl, button, ctrl, alt, shift, command, true, true)
    end)
    buttonMoveTotalUpControl:SetMouseEnabled(false)

    local buttonMoveTotalDownControl = wm:CreateControl(controlName .. "_ButtonMoveTotalDown", scrollListControl, CT_BUTTON)
    buttonMoveTotalDownControl:SetDimensions(16, 16)
    buttonMoveTotalDownControl:SetNormalTexture("/esoui/art/chatwindow/chat_scrollbar_endarrow_up.dds")
    buttonMoveTotalDownControl:SetMouseOverTexture("/esoui/art/chatwindow/chat_scrollbar_endarrow_over.dds")
    buttonMoveTotalDownControl:SetPressedMouseOverTexture("/esoui/art/chatwindow/chat_scrollbar_endarrow_down.dds")
    buttonMoveTotalDownControl:SetPressedTexture("/esoui/art/chatwindow/chat_scrollbar_endarrow_down.dds")
    buttonMoveTotalDownControl:SetDisabledTexture("/esoui/art/chatwindow/chat_scrollbar_endarrow_disabled.dds")
    buttonMoveTotalDownControl:SetPressedOffset(2, 2)
    buttonMoveTotalDownControl:SetAnchor(TOP, buttonMoveDownControl, BOTTOM, 0, 4)
    buttonMoveTotalDownControl:SetHidden(true)
    buttonMoveTotalDownControl:SetClickSound("Click")
    buttonMoveTotalDownControl.data = {tooltipText = util.GetStringFromValue(translations[lang].TOTAL_DOWN)}
    buttonMoveTotalDownControl:SetHandler("OnMouseEnter", function(button)
        if selfVar.disabled then return end
        ZO_Options_OnMouseEnter(button)
        wm:SetMouseCursor(MOUSE_CURSOR_UI_HAND)
    end)
    buttonMoveTotalDownControl:SetHandler("OnMouseExit", function(button)
        if selfVar.disabled then return end
        ZO_Options_OnMouseExit(button)
        wm:SetMouseCursor(MOUSE_CURSOR_DO_NOT_CARE)
    end)
    buttonMoveTotalDownControl:SetHandler("OnClicked", function(buttonCtrl, button, ctrl, alt, shift, command)
        if selfVar.disabled then return end
        onButtonClicked(buttonCtrl, button, ctrl, alt, shift, command, false, true)
    end)
    buttonMoveTotalDownControl:SetMouseEnabled(false)

    --Are the buttons disabled?
    self.isDragDisabled, self.areButtonsDisabled = getDisabledInfoFromListBoxData(orderListBoxData)
    updateButtonsEnabledState(control, self.areButtonsDisabled, orderListBoxData, buttonMoveUpControl, buttonMoveDownControl, buttonMoveTotalUpControl, buttonMoveTotalDownControl)

    --Show the position number in front of the row entry text?
    self.showPosition = getShowPositionInfoFromListBoxData(orderListBoxData)

    --OrderListBox datatype and data population + commit to show the entries
    --[[
		https://github.com/esoui/esoui/blob/e554eb0d0a24ad9b49c0a775a1e18babf8ef54d4/esoui/libraries/zo_templates/scrolltemplates.lua#L789
		ZO_ScrollList_AddDataType(control self, number typeId, string templateName, number height, function setupCallback, function hideCallback, dataTypeSelectSound, function:nilable resetControlCallback)
		This function registers a data type for the list to display.
		The dataTypeId must be unique to this data type. It's okay if data types in completely different scroll lists have the same identifiers.
		The templateName is the name of the virtual control that will be used to create list item controls for this data type.
		The setupFunction is a function that will be used to set up a list item control. It will be passed two arguments: the list item control, and the list item data.
		The dataTypeSelectSound will be played when a row of this type is selected.
		The resetControlCallback will be called when a list item control goes out of use.
	]]
    local dataTypeId = LAM_SORT_LIST_BOX_SCROLL_LIST_DATATYPE

    --Get the row XML templates and callback functions, sound etc.
    self.rowHeight, self.rowTemplate, self.rowFont, self.rowMaxLineCount, self.rowSelectionTemplate, self.rowSelectedCallback, self.rowHideCallback, self.dataTypeSelectSound, self.dataTypeResetControlCallback = getRowInfoFromOrderListBoxData(orderListBoxData)

    local templateName = self.rowTemplate
    local selectTemplate = self.rowSelectionTemplate

    local rowHeight = self.rowHeight

    local dataTypeSelectSound = self.dataTypeSelectSound

    local rowHideCallback = self.rowHideCallback
    local resetControlCallback = self.dataTypeResetControlCallback

    local setupFunction = function(control, data, scrollList)
        selfVar:RowSetupFunction(control, data, scrollList)
    end
    local selectCallback = function(previouslySelectedData, selectedData, reselectingDuringRebuild)
        --Check the disabled state of the LAM control and do not select any entry if it is disabled
        if selfVar.disabled then return end
        selfVar:OnRowSelected(previouslySelectedData, selectedData, reselectingDuringRebuild, buttonMoveUpControl, buttonMoveDownControl, buttonMoveTotalUpControl, buttonMoveTotalDownControl)
        if selfVar.rowSelectedCallback ~= nil and type(selfVar.rowSelectedCallback) == "function" then
            selfVar.rowSelectedCallback(selfVar, previouslySelectedData, selectedData, reselectingDuringRebuild)
        end
    end

    ZO_ScrollList_AddDataType(scrollListControl, dataTypeId, templateName, rowHeight, setupFunction, rowHideCallback, dataTypeSelectSound, resetControlCallback)
    ZO_ScrollList_EnableSelection(scrollListControl, selectTemplate, selectCallback)

    --Will be done via UpdateValue -> GetFunc
    --self.masterList = self:Populate(orderListBoxData)
    --self:UpdateScrollList(scrollListControl, self.masterList, dataTypeId)

    return scrollListControl, buttonMoveUpControl, buttonMoveDownControl, buttonMoveTotalUpControl, buttonMoveTotalDownControl
end


--Build the scroll list entries
function OrderListBox:Populate(orderListBoxData)
--d("[LAM2]OrderListBox:Populate")
    local masterList = orderListBoxData.listEntries or {}

    --[[
        [1] = {
            uniqueKey = 1, --number of the unique key of this list entry. This will not change if the order changes. Will be used to identify the entry uniquely
            value = "Value of the entry", -- or number or boolean or function returning the value of this entry
            text  = "Text of this entry", -- or string id or function returning a string (optional)
            tooltip = "Tooltip text shown at this entry", -- or string id or function returning a string (optional)
        },
    ]]

    --2 example entries
    --[[
    if masterList == nil or #masterList == 0 then
        masterList[1] = {
            uniqueKey = 1,
            value = 1,
            text = "Test Entry 1",
            tooltip = "Test description 1",
        }
        masterList[2] = {
            uniqueKey = 2,
            value = 2,
            text = "Test Entry 2",
            tooltip = "Test description 2",
        }
    end
    ]]

    return masterList
end


--------------------------------------------------
-- Update any changes to a scroll list data table then commit those changes to the screen
-- Repeat this step as needed if you have a data table that will have changing data (like an inventory).
--------------------------------------------------
function OrderListBox:UpdateScrollList(control, data, rowDataType, lamControl)
--d("[LAM2]OrderListBox:UpdateScrollList")
	--[[ 	Adds data to the datalist. Already stored in the control rowtype is the typeId we assigned in CreateScrollListDataType.

			From LibScroll:
			"Must use ZO_DeepTableCopy or it WILL crash if the user passes in a dataTable that is stored in saved variables.
			This is because ZO_ScrollList_CreateDataEntry creates a recursive reference to the data.
			Although this is only necessary for data saved in saved vars, I'm doing it to protect users against themselves"
	--]]
	local dataCopy = ZO_DeepTableCopy(data)
	local dataList = ZO_ScrollList_GetDataList(control)

	-- Clears out the scroll list.  Dont' worry, we made a copy called dataList.
	ZO_ScrollList_Clear(control)

	-- Create the data entries for the scroll list from the copy of the new data table.
	for key, value in ipairs(dataCopy) do
		local entry = ZO_ScrollList_CreateDataEntry(rowDataType, value)
		table.insert(dataList, entry) -- By using table.insert, we add to whatever data may already be there.
	end

	-- Sort if needed.  In our case we want to sort by the text
	--table.sort(dataList, function(a,b) return a.data.text < b.data.text end)

	-- Redraw the scroll list.
    --> Not if the LAM control is currently building, as the UpdateDisabled function will call the commit then!
    if lamControl.isBuilding == true then return end
	ZO_ScrollList_Commit(control)
end


--Row get's created/setup callback function
function OrderListBox:RowSetupFunction(rowControl, data, scrollList)
    -- The rowControl, data, and scrollListControl are all supplied by the internal callback trigger
    -- What is contained in data is determined by the structure of the table of data items you used in the Populate function
    rowControl:SetFont(self.rowFont)
    rowControl:SetMaxLineCount(self.rowMaxLineCount) -- 1 = Forces the text to only use one row
    if self.showPosition then
        rowControl:SetText(tostring(rowControl.index) .. ") " .. data.text)
    else
        rowControl:SetText(data.text)
    end

    -- When we added the data type earlier we also enabled being able to select an item and which function to run
    -- when an row is slected.  We still need to set up a handler to actuall register the mouse click which
    -- then triggers the row as "selected".  See https://wiki.esoui.com/UI_XML#OnAddGameData and following
    -- entries for "On" events that can be set as handlers.
    rowControl:SetHandler("OnMouseUp", function(p_rowControl, mouseButton, upInside, ctrl, alt, shift, command)
--d(">OnMouseUp - upInside: " ..tostring(upInside) .. ", mouseButton: " ..tostring(mouseButton) .. ", draggingEntryId: " .. tostring(self.draggingEntryId))
        if self.disabled then return end
        self.mouseDown = nil
        if not upInside or mouseButton ~= MOUSE_BUTTON_INDEX_LEFT then return end
        wm:SetMouseCursor(MOUSE_CURSOR_UI_HAND)
        if self.draggingEntryId ~= nil then return end
        ZO_ScrollList_MouseClick(scrollList, p_rowControl)
    end)
    rowControl:SetHandler("OnMouseDown", function(p_rowControl, mouseButton, ctrl, alt, shift, command)
--d("row OnMouseDown - mouseButton: " .. tostring(mouseButton) .. ", draggingId: " ..tostring(self.draggingEntryId))
        if self.disabled then return end
        self.mouseDown = true
        if self.draggingEntryId == nil then
            --Is the left mouse pressed down (before dragging)
            if mouseButton == MOUSE_BUTTON_INDEX_LEFT and not self.isDragDisabled then
                wm:SetMouseCursor(MOUSE_CURSOR_RESIZE_NS)
            else
                wm:SetMouseCursor(MOUSE_CURSOR_UI_HAND)
            end
        else
            wm:SetMouseCursor(MOUSE_CURSOR_RESIZE_NS)
        end
    end)

    local tooltip = data.tooltip
    rowControl:SetHandler("OnMouseEnter", function(p_rowControl)
--d(">OnMouseEnter, draggingEntryId: " .. tostring(self.draggingEntryId))
        if self.disabled then return end
        local isMouseDown = self.mouseDown
        if self.draggingEntryId == nil and not isMouseDown then
            wm:SetMouseCursor(MOUSE_CURSOR_UI_HAND)
        end
        if not isMouseDown then
            ZO_Tooltips_ShowTextTooltip(p_rowControl, LEFT, tooltip)
        end
    end)
    rowControl:SetHandler("OnMouseExit", function(p_rowControl)
--d(">OnMouseExit, draggingEntryId: " .. tostring(self.draggingEntryId))
        if self.disabled then return end
        if self.draggingEntryId == nil and not self.mouseDown then
            wm:SetMouseCursor(MOUSE_CURSOR_DO_NOT_CARE)
        end
        ZO_Tooltips_HideTextTooltip()
    end )
    rowControl:SetHidden(false)
    rowControl:SetMouseEnabled(not self.disabled)
end


--Row was selected callback function
function OrderListBox:OnRowSelected(previouslySelectedData, selectedData, reselectingDuringRebuild, buttonMoveUpControl, buttonMoveDownControl, buttonMoveTotalUpControl, buttonMoveTotalDownControl)
--d(">OnRowSelected, draggingEntryId: " .. tostring(self.draggingEntryId))
    if self.disabled then return end
    if not selectedData then
        buttonMoveUpControl:SetMouseEnabled(false)
        buttonMoveUpControl:SetHidden(true)
        buttonMoveDownControl:SetMouseEnabled(false)
        buttonMoveDownControl:SetHidden(true)
        buttonMoveTotalUpControl:SetMouseEnabled(false)
        buttonMoveTotalUpControl:SetHidden(true)
        buttonMoveTotalDownControl:SetMouseEnabled(false)
        buttonMoveTotalDownControl:SetHidden(true)
    else
        local selectedIndex = ZO_ScrollList_GetSelectedDataIndex(self.scrollListControl)
        if not selectedIndex then return end
        self:UpdateMoveButtonsEnabledState(selectedIndex)
    end
end


--Move an entry of the list up or down
function OrderListBox:MoveItem(selectedIndex, moveUp, moveToIndex, moveToTopOrBottom)
    if self.disabled then return end
    local movedUp
    if moveUp == nil and moveToIndex == nil then return end
    local scrollListControl = self.scrollListControl
    if not ZO_ScrollList_HasVisibleData(scrollListControl) then return end
    selectedIndex = selectedIndex or ZO_ScrollList_GetSelectedDataIndex(scrollListControl)
    if selectedIndex == nil then return end
    --d(string.format("[LAM2]OrderListBox:MoveItem - selectedIndex: %s, moveUp: %s", tostring(selectedIndex), tostring(moveUp)))
    --Get the current data table of the list
    local currentData = scrollListControl.data
    if not currentData then return end
    local maxEntries = #currentData
    local entryToMove = self.orderListBoxData.listEntries[selectedIndex]
    if not entryToMove then return end
    --d(">entryToMove: " ..tostring(entryToMove.text))
    --Move item up by 1
    local newIndex
    if moveUp == true and selectedIndex > 1 then
        newIndex = (moveToTopOrBottom ~= nil and moveToTopOrBottom == true and 1) or selectedIndex - 1
        table.remove(self.orderListBoxData.listEntries, selectedIndex)
        table.insert(self.orderListBoxData.listEntries, newIndex, entryToMove)
        movedUp = true

        --Move item down by 1
    elseif moveUp == false and selectedIndex < maxEntries then
        --d(">move 1 down")
        newIndex = (moveToTopOrBottom ~= nil and moveToTopOrBottom == true and maxEntries) or selectedIndex + 1
        table.remove(self.orderListBoxData.listEntries, selectedIndex)
        table.insert(self.orderListBoxData.listEntries, newIndex, entryToMove)
        movedUp = false
    elseif moveUp == nil and moveToTopOrBottom == nil and moveToIndex ~= nil and moveToIndex >= 1 and moveToIndex <= maxEntries then
        newIndex = moveToIndex
        table.remove(self.orderListBoxData.listEntries, selectedIndex)
        table.insert(self.orderListBoxData.listEntries, newIndex, entryToMove)
    else
        return
    end

    --Refresh the list contents! Will remove selection
    UpdateValue(self.control, false, self.orderListBoxData.listEntries)

    local wasMovedToLastEntry = newIndex == maxEntries
    local wasMovedToFirstEntry = newIndex == 1

    zo_callLater(function()
        local scrollBar = scrollListControl.scrollbar
        local valueMin, valueMax = scrollBar:GetMinMax()
        valueMin = valueMin or 0
        valueMax = valueMax or 9999
--d(">wasMovedToLastEntry: " ..tostring(wasMovedToLastEntry) .. ", wasMovedToFirstEntry: " ..tostring(wasMovedToFirstEntry) .. ", moveUp: " ..tostring(moveUp) .. ", valueMin/valueMax: " ..tostring(valueMin).."/" ..tostring(valueMax))

        if moveUp == nil then
            --Select the dragged & dropped entry now
            if wasMovedToLastEntry then
                ZO_ScrollList_ScrollAbsolute(scrollListControl, valueMax)
                ZO_ScrollList_SelectData(scrollListControl, scrollListControl.data[newIndex].data, nil, nil, true)
            elseif wasMovedToFirstEntry then
                ZO_ScrollList_ResetToTop(scrollListControl)
                ZO_ScrollList_SelectData(scrollListControl, scrollListControl.data[newIndex].data, nil, nil, true)
            else
                ZO_ScrollList_SelectDataAndScrollIntoView(scrollListControl, scrollListControl.data[newIndex].data, nil, false)
            end
        else
            if wasMovedToLastEntry then
                ZO_ScrollList_ScrollAbsolute(scrollListControl, valueMax)
                ZO_ScrollList_SelectData(scrollListControl, scrollListControl.data[newIndex].data, nil, nil, true)
            elseif wasMovedToFirstEntry then
                ZO_ScrollList_ResetToTop(scrollListControl)
                ZO_ScrollList_SelectData(scrollListControl, scrollListControl.data[newIndex].data, nil, nil, true)
            else
                --Reselect the last moved entry now and scroll it into view
                --Therefor we manually need to set the selectedDataIndex here without selecting a control
                -->(selection of the last moved control was removed at UpdateValue -> scrollList:Commit())
                scrollListControl.selectedDataIndex = selectedIndex
                if movedUp == true then
                    ZO_ScrollList_SelectPreviousData(scrollListControl, nil, false)
                else
                    ZO_ScrollList_SelectNextData(scrollListControl, nil, false)
                end
            end
        end
        self:UpdateMoveButtonsEnabledState(newIndex)
    end, 100)
end


function OrderListBox:UpdateMoveButtonsEnabledState(newIndex)
--d("[LAM2 OrderListBox]UpdateMoveButtonsEnabledState")
    if self.disabled or self.areButtonsDisabled then return end
    if not newIndex then return end
    self.moveUpButton:SetHidden(false)
    self.moveDownButton:SetHidden(false)
    self.moveTotalUpButton:SetHidden(false)
    self.moveTotalDownButton:SetHidden(false)
    if newIndex == 1 then
        self.moveUpButton:SetMouseEnabled(false)
        self.moveUpButton:SetHidden(true)
        self.moveDownButton:SetMouseEnabled(true)
        self.moveTotalUpButton:SetMouseEnabled(false)
        self.moveTotalUpButton:SetHidden(true)
        self.moveTotalDownButton:SetMouseEnabled(true)
    elseif newIndex == #self.scrollListControl.data then
        self.moveUpButton:SetMouseEnabled(true)
        self.moveDownButton:SetMouseEnabled(false)
        self.moveDownButton:SetHidden(true)
        self.moveTotalUpButton:SetMouseEnabled(true)
        self.moveTotalDownButton:SetMouseEnabled(false)
        self.moveTotalDownButton:SetHidden(true)
    else
        self.moveUpButton:SetMouseEnabled(true)
        self.moveDownButton:SetMouseEnabled(true)
        self.moveTotalUpButton:SetMouseEnabled(true)
        self.moveTotalDownButton:SetMouseEnabled(true)
    end
end

--Auto scroll the orderListBox upon dragging an entry to the top/bottom of the list
local function autoScroll(orderListBoxVar)
--d(">autoscroll")
    local scrollListControl = orderListBoxVar.scrollListControl
    local contents = scrollListControl.contents
    local numContentChildren = (contents ~= nil and contents:GetNumChildren()) or 0
    local contentsHeight = contents:GetHeight()
    if not contents or numContentChildren == 0 then return end
    local controlBelowMouse = moc()
    if not controlBelowMouse or not controlBelowMouse.GetParent or controlBelowMouse:GetParent() ~= contents then return end
    local isValid, point, relTo, relPoint, offsetX, offsetY = controlBelowMouse:GetAnchor(0)
    local orderListBoxRowHeight = orderListBoxVar.rowHeight or SORT_LIST_ROW_DEFAULT_HEIGHT
    local orderListBoxScrollArea = orderListBoxRowHeight * 1.5
    local scrollValue
    if offsetY < 0 or (offsetY >= 0 and offsetY <= orderListBoxScrollArea) then
        --Scroll up
        scrollValue = (orderListBoxRowHeight * 2) * -1
    elseif offsetY <= contentsHeight and offsetY >= contentsHeight - orderListBoxScrollArea then
        --Scroll down
        scrollValue = orderListBoxRowHeight * 2
    end
    if scrollValue == nil or scrollValue == 0 then return end
--d(">scrollValue: " ..tostring(scrollValue))
    ZO_ScrollList_ScrollRelative(scrollListControl, scrollValue, nil, true)
end

function OrderListBox:OnGlobalMouseDownDuringDrag(eventId, mouseButton, ctrl, alt, shift, command)
--d("[OrderListBox]OnGlobalMouseDownDuringDrag - draggedIndex: " ..tostring(self.draggingEntryId) .. ", mouseButton: " ..tostring(mouseButton))
    if self.disabled or self.isDragDisabled then return end
    if self.draggingEntryId and self.draggingSortListContents then
        self.mouseButtonPressed = mouseButton
    end
end

function OrderListBox:OnGlobalMouseUpDuringDrag(eventId, mouseButton, ctrl, alt, shift, command)
--d("[OrderListBox]OnGlobalMouseUpDuringDrag - draggedIndex: " ..tostring(self.draggingEntryId) .. ", mouseButton: " ..tostring(mouseButton))
    if self.disabled or self.isDragDisabled then return end
    if mouseButton ~= MOUSE_BUTTON_INDEX_LEFT then
        abortDragging(self)
        wm:SetMouseCursor(MOUSE_CURSOR_DO_NOT_CARE)
    end
    if self.draggingEntryId and self.draggingSortListContents then
        local controlBelowMouse = moc()
        if not controlBelowMouse or controlBelowMouse and controlBelowMouse:GetParent() ~= self.draggingSortListContents then
            abortDragging(self)
            wm:SetMouseCursor(MOUSE_CURSOR_DO_NOT_CARE)
        end
    end
end

function OrderListBox:UpdateCursorTLC(isHidden, draggedControl)
    if cursorTLC == nil then getCursorTLC() end
    if not cursorTLC then return end
    cursorTLC:ClearAnchors()
    cursorTLC:SetResizeToFitDescendents(true)
    if not isHidden then
        cursorTLC.orderListBox = self
        cursorTLC:SetAnchor(LEFT, GuiMouse, RIGHT, 5, 0)
        cursorTLCLabel:SetText(self.draggingText)
        local textWidth = (cursorTLCLabel:GetTextWidth()) + 2
        cursorTLCLabel:SetWidth(textWidth)
        cursorTLCLabel:SetHeight(self.rowHeight or SORT_LIST_ROW_DEFAULT_HEIGHT)
        cursorTLC:SetWidth(textWidth)
        cursorTLC:SetHeight(self.rowHeight or SORT_LIST_ROW_DEFAULT_HEIGHT)
        local width, height = cursorTLCLabel:GetDimensions()
        if width > 600 then width = 600 end
        if height > 100 then height = 100 end
--d(">GuiMouse:isHidden: " ..tostring(GuiMouse:IsHidden()) .. ", cursorTLC.width: " ..tostring(cursorTLC:GetWidth()) ..", cursorTLC.height: " ..tostring(cursorTLC:GetHeight()) .. ", text: " ..tostring(self.draggingText))
        cursorTLC:SetDimensionConstraints(width, height, 600, 100)
        cursorTLC:SetDrawTier(DT_HIGH)
        cursorTLC:SetDrawLayer(DL_OVERLAY)
        cursorTLC:SetDrawLevel(5)
        cursorTLC:SetAlpha(0.7)
    else
        cursorTLC.orderListBox = nil
        cursorTLC:SetDimensions(0, 0)
        cursorTLCLabel:SetText("")
        cursorTLC:SetDrawTier(DT_LOW)
        cursorTLC:SetDrawLayer(DL_BACKGROUND)
        cursorTLC:SetDrawLevel(0)
        cursorTLC:SetAlpha(0)
    end
    cursorTLC:SetHidden(isHidden)
    cursorTLC:SetMouseEnabled(false)
end

function OrderListBox:DragOnUpdateCallback(draggedControl)
    if self.disabled or self.isDragDisabled then
        abortDragging(self)
        return
    end

    --Check the actual shown rows of the list (contents)
    -->Check the anchor's offsetY of the row of the contents. If between 0 and 2*rowHeight -> Scroll up
    -->If between contents:GetHeight()- 2*rowHeight and contents:GetHeight() -> Scroll down
    --Only run the following code once every 500 MS!
    local gameTimeMS = GetGameTimeMilliseconds()
    local gameTimeDeltaNeeded = 200 --milliseconds
--d("[LAM2OrderListBox]OnUpdate-gameTime: " ..tostring(gameTimeMS) .. ", self.draggingUpdateTime: " ..tostring(self.draggingUpdateTime))
    local updateAutoScroll = false
    if self.draggingUpdateTime == nil then
        self.draggingUpdateTime = gameTimeMS
        updateAutoScroll = true
    elseif self.draggingUpdateTime > 0 then
        if gameTimeMS >= (self.draggingUpdateTime + gameTimeDeltaNeeded) then
            self.draggingUpdateTime = gameTimeMS
            updateAutoScroll = true
        end
    end
--d(">updateAutoScroll: " .. tostring(updateAutoScroll) ..", needed: " ..tostring(self.draggingUpdateTime + gameTimeDeltaNeeded))
    if updateAutoScroll == true then
        autoScroll(self)
    end
end

function OrderListBox:StartDragging(draggedControl, mouseButton)
--d("StartDragging")
    local selfVar = self
    if self.disabled or selfVar.isDragDisabled then return end
    if mouseButton ~= MOUSE_BUTTON_INDEX_LEFT then return end
    --d("[OrderListBox]StartDragging - index: " ..tostring(draggedControl.index))
    self.draggingEntryId            = draggedControl.index
    self.draggingSortListContents   = draggedControl:GetParent()
    self.draggingText               = draggedControl.dataEntry.data.text
    self.mouseButtonPressed         = MOUSE_BUTTON_INDEX_LEFT

    --Anchor the TLC with the label of the dragged row element to GuiMouse
    self:UpdateCursorTLC(false, draggedControl)

    wm:SetMouseCursor(MOUSE_CURSOR_RESIZE_NS)
    --Unselect any selected entry
    ZO_ScrollList_SelectData(self.scrollListControl, nil, nil, nil, true)
    --Enable a global MouseUp check and see if the mouse is above the ZO_SortList where the drag started
    --If not: End the drag&drop
    em:RegisterForEvent(EVENT_HANDLER_NAMESPACE .. "_GLOBAL_MOUSE_DOWN", EVENT_GLOBAL_MOUSE_DOWN, function(...) selfVar:OnGlobalMouseDownDuringDrag(...) end)
    em:RegisterForEvent(EVENT_HANDLER_NAMESPACE .. "_GLOBAL_MOUSE_UP", EVENT_GLOBAL_MOUSE_UP, function(...) selfVar:OnGlobalMouseUpDuringDrag(...) end)

    --Set the OnUpdate handler to check for the autosroll position of the cursor
    self.draggingUpdateTime = nil
    self.scrollListControl:SetHandler("OnUpdate", function() selfVar:DragOnUpdateCallback(draggedControl) end)
end


function OrderListBox:StopDragging(draggedOnToControl)
    --Delay so the OnMouseButtonDown/Up handlers fire first
    zo_callLater(function()
        local mouseButton = self.mouseButtonPressed
    --d("StopDragging - mouseButton: " ..tostring(mouseButton))
        if self.disabled or self.isDragDisabled then return end
        disableOnUpdateHandlerAndResetMouseCursor(self)
        wm:SetMouseCursor(MOUSE_CURSOR_UI_HAND)
        if mouseButton and mouseButton == MOUSE_BUTTON_INDEX_LEFT and self.draggingEntryId ~= nil and self.draggingSortListContents ~= nil then
            --local totalDeltaX = GetUIMousePosition() - self.draggingXStart
            --local lastFrameDeltaX = GetUIMouseDeltas() * 15
            --self:SetSelectedIndex(zo_round((self:CalculateSelectedIndexOffset() + totalDeltaX + lastFrameDeltaX) / self.controlEntryWidth))
    --d("[OrderListBox]StopDragging -- from index: " ..tostring(self.draggingEntryId) .." to index: " ..tostring(draggedOnToControl.index))
            --Remove the entry at index self.draggingEntryId and insert it at draggedOnToControl.dataEntry.data.index
            self:MoveItem(self.draggingEntryId, nil, draggedOnToControl.index, nil)
        end
        clearDragging(self)
    end, 50)
end


function  LAM2_orderlistbox_widget_OnDragStart(draggedControl, mouseButton)
--d("[LAM2_orderlistbox_widget_OnDragStart] - " ..tostring(draggedControl.dataEntry.data.text))
    local orderListBox = draggedControl:GetParent():GetParent():GetParent().orderListBox
    orderListBox:StartDragging(draggedControl, mouseButton)
end
function  LAM2_orderlistbox_widget_OnReceiveDrag(draggedOnToControl, mouseButton)
--d("[LAM2_orderlistbox_widget_OnReceiveDrag] - " ..tostring(draggedOnToControl.dataEntry.data.text))
    local orderListBox = draggedOnToControl:GetParent():GetParent():GetParent().orderListBox
    orderListBox:StopDragging(draggedOnToControl, mouseButton)
end


------------------------------------------------------------------------------------------------------------------------
--The orderlistbox widget
------------------------------------------------------------------------------------------------------------------------
function LAMCreateControl.orderlistbox(parent, orderListBoxData, controlName)
    local control = util.CreateLabelAndContainerControl(parent, orderListBoxData, controlName)
    control.isBuilding = true

    local container = control.container

    local width = control:GetWidth()
    local minHeight = (control.data.minHeight and util.GetDefaultValue(control.data.minHeight)) or MIN_HEIGHT
    local maxHeight = (control.data.maxHeight and util.GetDefaultValue(control.data.maxHeight)) or (minHeight * 4)

    local isExtraWide = (orderListBoxData.isExtraWide and LAMgetDefaultValue(orderListBoxData.isExtraWide)) or false
    if isExtraWide == true then
        control.container:SetDimensionConstraints(width, minHeight, width, maxHeight)

        control.label:ClearAnchors()
        control.label:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)

        container:ClearAnchors()
        container:SetAnchor(BOTTOMLEFT, control, BOTTOMLEFT, 0, 0)
        container:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, 0, 0)

        if control.isHalfWidth then
            container:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, 0, 0)
        end
        control:SetHeight(container:GetHeight() + control.label:GetHeight())
    else
        control:SetDimensionConstraints(width, minHeight, width, maxHeight)
    end

    control:SetHandler("OnMouseEnter", function() ZO_Options_OnMouseEnter(control) end)
    control:SetHandler("OnMouseExit", function() ZO_Options_OnMouseExit(control) end)

    control.orderListBox = OrderListBox:New(util.GetTopPanel(parent), control, orderListBoxData)

    if orderListBoxData.warning ~= nil or orderListBoxData.requiresReload then
        control.warning = wm:CreateControlFromVirtual(nil, control, "ZO_Options_WarningIcon")
        control.warning:SetAnchor(RIGHT, control.container, LEFT, -5, 0)
        control.UpdateWarning = util.UpdateWarning
        control:UpdateWarning()
    end

    control.data.tooltipText = util.GetStringFromValue(orderListBoxData.tooltip)

    control.UpdateValue = UpdateValue
    control:UpdateValue()

    control.UpdateDisabled = UpdateDisabled
    control:UpdateDisabled()

    control.isBuilding = false

    util.RegisterForRefreshIfNeeded(control)
    util.RegisterForReloadIfNeeded(control)

    return control
end

local function registerWidget(eventId, addonName)
    if addonName ~= "LibAddonMenuOrderListBox" then return end
    em:UnregisterForEvent("LibAddonMenuOrderListBox_EVENT_ADD_ON_LOADED", EVENT_ADD_ON_LOADED)

    cursorTLC = getCursorTLC()

    if not LAM:RegisterWidget("orderlistbox", widgetVersion) then return end
    --Register a callback to the close of the LAM panel to hide a dragged control e.g. if ESC key was pressed
    cm:RegisterCallback("LAM-PanelClosed", checkIfDraggedAndDisableUpdateHandler)
end

em:RegisterForEvent("LibAddonMenuOrderListBox_EVENT_ADD_ON_LOADED", EVENT_ADD_ON_LOADED, registerWidget)
