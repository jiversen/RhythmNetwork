//
//  RTAssert.h
//  RhythmNetwork
//
//  Created by ChatGPT and John R. Iversen on 2025-07-17.
//

#ifndef RTAssert_h
#define RTAssert_h

#include <os/log.h>

#ifndef NDEBUG

#define RT_SAFE_ASSERT(expr, fmt, ...) \
	do { \
		if (__builtin_expect(!(expr), 0)) { \
			os_log_error(OS_LOG_DEFAULT, "ASSERTION FAILED: (%s) — " fmt, #expr, ##__VA_ARGS__); \
			__builtin_trap(); \
		} \
	} while (0)

#else

#define RT_SAFE_ASSERT(expr, fmt, ...) do { (void)(expr); } while (0)

#endif // NDEBUG

#endif /* RTAssert_h */
