/**
 * 
 * Motivation: avoid stack overflow using fgets and length checks
 */

#include <stdio.h>
#include <string.h>

void safe_func(void) {
    char buff[16];
    unsigned int target = 0x00abcd00;

    printf("--- inside safe_func() ---\n");
    printf("address of buff   : %p\n", (void *)buff);
    printf("address of target : %p\n", (void *)&target);
    printf("initial target    : 0x%08x\n", target);

    printf("Enter a string (max %zu chars): ", sizeof(buff)-1);
    if (!fgets(buff, sizeof(buff), stdin)) {
        puts("input error");
        return;
    }

    /*strip newline if present*/
    buff[strcspn(buff, "\n")] = '\0';

    printf("You entered: %s\n", buff);
    printf("after input, target : 0x%08x\n", target);
    printf("-----------------------\n");
}

int main(void) {
    printf("Starting safe\n");
    safe_func();
    printf("Done.");
    return 0;
}