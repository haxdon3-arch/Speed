#include <substrate.h>
#include <sys/time.h>
#include <mach/mach_time.h>
#include <dispatch/dispatch.h>

// ปรับความเร็วตรงนี้ (5.0 = เร็วขึ้น 5 เท่า)
static float speedMultiplier = 5.0f; 
static bool isSafeToSpeedUp = false; // สวิตช์นิรภัย ป้องกันเน็ตพังตอนเข้าเกม

static int (*orig_gettimeofday)(struct timeval *tv, struct timezone *tz);
static int hook_gettimeofday(struct timeval *tv, struct timezone *tz) {
    int ret = orig_gettimeofday(tv, tz);
    if (ret == 0 && tv != NULL) {
        static struct timeval base_tv = {0};
        
        if (base_tv.tv_sec == 0) {
            base_tv = *tv; // เก็บค่าเริ่มต้น
        } else if (isSafeToSpeedUp) {
            // ถ้าปลอดภัยแล้ว เริ่มเร่งเวลาได้
            long long diff_usec = (tv->tv_sec - base_tv.tv_sec) * 1000000LL + (tv->tv_usec - base_tv.tv_usec);
            long long speed_diff = diff_usec * speedMultiplier;
            tv->tv_sec = base_tv.tv_sec + (speed_diff / 1000000LL);
            tv->tv_usec = base_tv.tv_usec + (speed_diff % 1000000LL);
        } else {
            // ช่วง 15 วิแรก ปล่อยเวลาเดินปกติไปก่อน อัพเดตฐานเวลาไปเรื่อยๆ
            base_tv = *tv;
        }
    }
    return ret;
}

__attribute__((constructor)) static void initialize_speedhack() {
    MSHookFunction((void *)gettimeofday, (void *)hook_gettimeofday, (void **)&orig_gettimeofday);
    
    // ตั้งเวลาดีเลย์ 15 วินาที (ปรับตัวเลข 15 ตรงนี้ได้ตามเวลาที่เกมใช้โหลดเข้าหน้าหลัก)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        isSafeToSpeedUp = true;
    });
}
