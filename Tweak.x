#include <substrate.h>
#include <sys/time.h>
#include <mach/mach_time.h>

// ปรับความเร็วตรงนี้ (5.0 = เร็วขึ้น 5 เท่า)
static float speedMultiplier = 5.0f; 

// ---------------------------------------------------------
// Hook 1: gettimeofday (C/C++ Engine ทั่วไป เช่น Cocos2d)
// ---------------------------------------------------------
static int (*orig_gettimeofday)(struct timeval *tv, struct timezone *tz);
static int hook_gettimeofday(struct timeval *tv, struct timezone *tz) {
    int ret = orig_gettimeofday(tv, tz);
    if (ret == 0 && tv != NULL) {
        static struct timeval base_tv = {0};
        if (base_tv.tv_sec == 0) {
            base_tv = *tv; // เก็บค่าเริ่มต้นครั้งแรก
        } else {
            // คำนวณเวลาที่ผ่านไปและคูณด้วย speedMultiplier
            long long diff_usec = (tv->tv_sec - base_tv.tv_sec) * 1000000LL + (tv->tv_usec - base_tv.tv_usec);
            long long speed_diff = diff_usec * speedMultiplier;
            tv->tv_sec = base_tv.tv_sec + (speed_diff / 1000000LL);
            tv->tv_usec = base_tv.tv_usec + (speed_diff % 1000000LL);
        }
    }
    return ret;
}

// ---------------------------------------------------------
// Hook 2: Unity Engine TimeScale (สำหรับเกม Unity / Unity Ads)
// ---------------------------------------------------------
float (*orig_get_timeScale)(void* instance);
float hook_get_timeScale(void* instance) {
    // ดึงค่าเวลาปกติแล้วคูณความเร็ว
    return orig_get_timeScale(instance) * speedMultiplier;
}

// ---------------------------------------------------------
// Constructor (ทำงานตอนโหลด dylib)
// ---------------------------------------------------------
__attribute__((constructor)) static void initialize_speedhack() {
    // Hook ระดับ OS Time
    MSHookFunction((void *)gettimeofday, (void *)hook_gettimeofday, (void **)&orig_gettimeofday);
    
    // Hook Unity (ต้องหา Offset ของ UnityEngine.Time::get_timeScale ใน il2cpp)
    // *ตัวอย่างสมมติว่าหา Offset เจอแล้วที่ 0x123456*
    // void* unityTimeScale = (void*)((uintptr_t)_dyld_get_image_header(0) + 0x123456);
    // MSHookFunction(unityTimeScale, (void *)hook_get_timeScale, (void **)&orig_get_timeScale);
}
