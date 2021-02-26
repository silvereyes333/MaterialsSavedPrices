local strings = {
    ["SI_MATSAVPRC_SAVING"] = "Сохранение цен на материалы ...",
}

-- Overwrite English strings
for stringId, value in pairs(strings) do
    MATSAVPRC_STRINGS[stringId] = value
end