function v = readAttOrDefault(h5f, path, attName, def)
try
    v = h5readatt(h5f, path, attName);
catch
    v = def;
end
end
