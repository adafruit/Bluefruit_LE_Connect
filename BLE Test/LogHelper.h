//
//  LogHelper.h
//  
//
//  Created by Antonio García on 12/09/14.
//  Copyright (c) 2014-2015 OpenRoad. All rights reserved.

// Log macros
#ifdef DEBUG
#   define DLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#   define DLog(...)
#endif

#define ALog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);


