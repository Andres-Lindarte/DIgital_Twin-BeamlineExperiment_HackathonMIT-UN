/**
 * @file util.h
 * Various utility functions.
 *
 * @author David Manura (c) 2003-2004 Scientific Instrument Services, Inc.
 * Licensed under the terms of the SIMION SL Toolkit.
 */

#ifndef SL_UTIL_H
#define SL_UTIL_H

#include <climits>
#include <cassert>
#include <iostream>
#include <sstream>
#include <cctype>
#include <cstdlib> // exit
#include <limits>
#ifdef WIN32
    #include <windows.h>
#endif

namespace simion
{

// may be more portable than stdint.h PTRDIFF_MIN/MAX.
const ptrdiff_t MY_PTRDIFF_MIN = std::numeric_limits<ptrdiff_t>::min();
const ptrdiff_t MY_PTRDIFF_MAX = std::numeric_limits<ptrdiff_t>::max();

inline void sl_assert_console(
    const std::string& file, int line, const std::string& function,
    const std::string message)
{
    std::cerr << "SL Libraries: Assertion failed: " <<
        "File (" << file << ") Function (" << function << ") Line # (" << line << "):\n" << message << std::endl;
    exit(1);
}

#ifdef WIN32
inline void sl_assert_win(
    const std::string& file, int line, const std::string& function,
    const std::string message)
{
    std::ostringstream os;
    os << "SL Libraries: Assertion failed: " <<
        "File (" << file << ") Function (" << function << ") Line # (" << line << "):\n" << message << std::endl;
    ::MessageBoxA(NULL, os.str().c_str(), "SL Libraries: Assertion failed.", MB_ICONSTOP);
    exit(1);
}
#endif
     


// note: compare to assert.h
#ifdef NDEBUG
#    define sl_assert(e,function,msg) ((void)0)
#else
#ifdef WIN32
#    define sl_assert(e,function,msg) ((e) ? (void)0 : sl_assert_win(__FILE__, __LINE__, function, msg))
#else
#    define sl_assert(e,function,msg) ((e) ? (void)0 : sl_assert_console(__FILE__, __LINE__, function, msg))
#endif
#endif

/**
 * Return whether x+y will overflow or underflow.
 */
inline bool add_overflow(ptrdiff_t x, ptrdiff_t y)
{
    bool overflow = ((x > 0) && (y > MY_PTRDIFF_MAX - x)) ||
                    ((x < 0) && (y < MY_PTRDIFF_MIN - x));
    return overflow;
}

/**
 * Return whether x*y will overflow or underflow.
 * Q:Is there a simpler way?
 */
inline bool mult_overflow(ptrdiff_t x, ptrdiff_t y)
{
    bool overflow =
        ((x > 0) && (y > 0) && (x > MY_PTRDIFF_MAX / y)) ||
        ((x < 0) && (y < 0) &&
            ((x == MY_PTRDIFF_MIN) || (y == MY_PTRDIFF_MIN) || (-x > MY_PTRDIFF_MAX / -y))) ||
        ((x < 0) && (y > 0) && (x < MY_PTRDIFF_MIN / y)) ||
        ((x > 0) && (y < 0) && (y < MY_PTRDIFF_MIN / x))
    ;
    return overflow;
}

template<class t>
inline std::string str(t val) {
    std::ostringstream os;
    os << val;
    return os.str();
}

inline std::string strtolower(const std::string& str)
{
    std::string ret(str);
    for(std::string::size_type n=0; n<ret.size(); n++)
        ret[n] = (char)tolower((char)ret[n]);
    return ret;
}

}

#endif // first include
