module dli.internal.to_wchar;

import std.conv : to, ConvException;

// Phobos does not implement to!(wchar, string), idk why
toT to(fromT : string, toT : wchar)(fromT from)
{
    import std.utf : byWchar;
    enforce!ConvException(from.length <= 2);
    foreach(wchar c; from.byWchar)
        return c;
}