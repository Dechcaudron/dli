/// Defines exceptions used and thrown by the library
module dli.exceptions;

import std.exception;

///
public class InvalidItemException : Exception
{
    ///
    mixin basicExceptionCtors;
}

///
public class InvalidKeyException : Exception
{
    ///
    mixin basicExceptionCtors;
}

///
public class InvalidMenuStatusException : Exception
{
    ///
    mixin basicExceptionCtors;
}

///
public class ItemBoundException : Exception
{
    ///
    mixin basicExceptionCtors;
}