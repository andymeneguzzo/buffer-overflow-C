/**
 * Motivation: show stack overflow that overwrites an adjacent stack variable
 */

#include <stdio.h>

void vuln(void) {
    struct pair {
        /*small buffer on the stack*/
        char buff[16];

        /*adjacent local to monitor for corruption*/
        unsigned int target;
    } p;
    p.target = 0x00abcd00;

    /*ensure prints are not lost in abort, so logs are printed correctly by the build_run.sh*/
    setvbuf(stdout, NULL, _IONBF, 0);
    setvbuf(stderr, NULL, _IONBF, 0);
    

    printf("--- inside vuln() ---\n");
    printf("address of buff   : %p\n", (void *)p.buff);
    printf("address of target : %p\n", (void *)&p.target);
    printf("initial target    : 0x%08x\n", p.target);

    /*UNSAFE - input with no width limit -> overflow*/
    printf("Enter a string (long input will overflow buff): ");
    fflush(stdout); // to be sure

    if (scanf("%s", p.buff) != 1) {
        printf("input error\n");
        return;
    }

    printf("You entered: %s\n", p.buff);
    printf("after input, target : 0x%08x\n", p.target);
    printf("-----------------------\n");
}

int main(void) {
    printf("Starting vuln\n");
    vuln();
    printf("Done.\n");
    return 0;
}