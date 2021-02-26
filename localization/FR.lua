local strings = {
    ["SI_MATSAVPRC_SAVING"] = "Sauvegarder les prix des matériaux …",
}

-- Overwrite English strings
for stringId, value in pairs(strings) do
    MATSAVPRC_STRINGS[stringId] = value
end