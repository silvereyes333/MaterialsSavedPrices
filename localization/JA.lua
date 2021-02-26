local strings = {
    ["SI_MATSAVPRC_SAVING"] = "素材値段をそのままセーブ…",
}

-- Overwrite English strings
for stringId, value in pairs(strings) do
    MATSAVPRC_STRINGS[stringId] = value
end