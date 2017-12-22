module dli.string_stream.eof_exception;

import std.exception;

public class EOFException : Exception
{
    //
    mixin basicExceptionCtors;
}