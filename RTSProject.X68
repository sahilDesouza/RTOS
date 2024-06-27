*-----------------------------------------------------------
* Title      : Realtime Operating System
* Written by : Sanjay, Sahil, Hamza
* Date       : Dec 22
* Description:  
*-----------------------------------------------------------
                                        ;system call equates
                                        
sys     equ     0                       ; system call trap (trap 0)
syscr   equ     1                       ; create new task
sysdel  equ     2                       ; delete task
syswtmx equ     3                       ; wait on mutex
syssgmx equ     4                       ; signal mutex
sysinmx equ     5                       ; initialise mutex 
syswttm equ     6                       ; wait on timer
syswtio equ     7                       ; wait on I/O interrupt
sysmemalc equ   8                       ; allocate memory  

usrcode equ     $2000                   ;address of user task 0
usrstk  equ     $4000                   ;address of user stack
ntcblst equ     8                       ;number of records in tcb list

tcb     org     0                       ;tcb record
tcbd0   ds.l    1                       ; D register save
tcbd1   ds.l    1
tcbd2   ds.l    1
tcbd3   ds.l    1
tcbd4   ds.l    1
tcbd5   ds.l    1
tcbd6   ds.l    1
tcbd7   ds.l    1
tcba0   ds.l    1                       ; A register save
tcba1   ds.l    1
tcba2   ds.l    1
tcba3   ds.l    1
tcba4   ds.l    1
tcba5   ds.l    1
tcba6   ds.l    1
tcba7   ds.l    1
tcbsr   ds.l    1                       ; SR (status reg) save
tcbpc   ds.l    1                       ; PC save          
tcbnext ds.l    1                       ; link to next record
tcbused ds.l    1                       ; record in use flag
tcbwtim ds.l    1                       ; timer wait expiry time
tcblen  equ     *                       ; length of tcb record, * returns the current location which happens to be the length of the tcb record

;******************************************************************************
rts                                     ;RUNTIME SYSTEM
;******************************************************************************

;******************************************************************************
                                        ;INTERRUPT VECTORS
;******************************************************************************

        org     0
        
        dc.l    usrstk                  ; initial SP
        dc.l    res                     ; reset
        ds.b    $5C
        dc.l    fltint                  ; interrupt 1 (timer)
        dc.l    slioint                 ; interrupt 2 (I/O)
        ds.b    $14
        dc.l    flsint                  ; trap 0 (system call)
;*******************************************************************************        
res                                     ;RESET
;*******************************************************************************
    move.l #tcblst,(rdytcb)
    move.l  #$00000000,wttcb
    move.l  #$00000000,iowttcb
    move.l  rdytcb,a0 
    move.l  rdytcb,tcbnext(a0)
    
    move.l  a0,a1
    move.l  #ntcblst,d0
    
    move.l  #ntcblst, syscrCount
    move.l  #ntcblst, sysdelCount
    move.l  #usrcode, UsrCodeAdd   
    move.l  #usrstk, UsrStkAdd  
    
        *create a loop to initialise tcbs
tcbinit

    move.l  #$00,tcbd0(a1)              ;init tcbs
    move.l  #$00,tcbd1(a1)       
    move.l  #$00,tcbd2(a1)
    move.l  #$00,tcbd3(a1) 
    move.l  #$00,tcbd4(a1)
    move.l  #$00,tcbd5(a1)       
    move.l  #$00,tcbd6(a1)
    move.l  #$00,tcbd7(a1) 
    move.l  #$00,tcba0(a1)
    move.l  #$00,tcba1(a1)       
    move.l  #$00,tcba2(a1)
    move.l  #$00,tcba3(a1) 
    move.l  #$00,tcba4(a1)
    move.l  #$00,tcba5(a1)       
    move.l  #$00,tcba6(a1)
    move.l  #0,tcbused(a1)               ;used flag
    move.l  #0,tcbwtim(a1)               ;wait time
    move.l  a1,tcbnext(a1)
    
    add.l   #tcblen,a1
    sub.l   #1,d0
    bne     tcbinit
    
    move.l  #1,tcbused(a0)
    
    move.l  #1,mutex                    ;set mutex as free   
    
    move.l  #usrstk,sp
    and     #$2000,sr
    
    move.l  #$00,d0              ;init registers
    move.l  #$00,d1       
    move.l  #$00,d2
    move.l  #$00,d3 
    move.l  #$00,d4
    move.l  #$00,d5       
    move.l  #$00,d6
    move.l  #$00,d7 
    move.l  #$00,a0
    move.l  #$00,a1       
    move.l  #$00,a2
    move.l  #$00,a3 
    move.l  #$00,a4
    move.l  #$00,a5       
    move.l  #$00,a6
    bra usrcode


        
;*******************************************************************************        
flih                                    ;FIRST-LEVEL INTERRUPT HANDLER
;*******************************************************************************

fltint                                  ;ENTRY FROM TIMER INTERRUPT  
        move.l  d0,d0sav                ;save D0
        
        move.l  #$0,d0                  ;set id = 0 as normal
        move.l  d0,id
        move.l  d0sav,d0                ;restore D0
        
        add.l  #$1,time                 ;update system time
        bra     fl1  
        
        


 
slioint
        move.l  d0,d0sav2                ;save D0
        move.l  a0,a0sav2                ;save A0
         
        
        move.l  #tcblst,a0
        move.l  #ntcblst,d0
        
        
ioreset
        move.l  d0,sliointcounter
  
        move.l  tcbwtim(a0),d0
        sub.l   #$FFFFFFFF,d0
        bne     skiptcb
        move.l  d0,tcbwtim(a0)    
                    
skiptcb  add.l   #tcblen,a0
        move.l  sliointcounter,d0
        sub.l   #1,d0
        bne     ioreset
    
        move.l  d0sav2,d0                ;restore D0
        move.l  a0sav2,a0                ;restore A0
        rte  

flsint                                  ;ENTRY FROM TRAP (SOFTWARE INTERRUPT)
        or      #%0000011100000000,sr   ;disable hardware interrupts
        move.l  d0,id                   ;store id
        bra     fl1
       
fl1     move.l  a0,a0sav                ;save working reg
        
        move.l  rdytcb,a0               ;A0 ^ 1st ready tcb (ie running tcb)
            
        move.l  d0,tcbd0(a0)            ;store registers
        move.l  d1,tcbd1(a0)       
        move.l  d2,tcbd2(a0)
        move.l  d3,tcbd3(a0) 
        move.l  d4,tcbd4(a0)
        move.l  d5,tcbd5(a0)       
        move.l  d6,tcbd6(a0)
        move.l  d7,tcbd7(a0)
        move.l  a0sav,d0 
        move.l  d0,tcba0(a0)
        move.l  a1,tcba1(a0)       
        move.l  a2,tcba2(a0)
        move.l  a3,tcba3(a0) 
        move.l  a4,tcba4(a0)
        move.l  a5,tcba5(a0)       
        move.l  a6,tcba6(a0)

        move    (sp),d0                 ;pop and store SR
        and     #$0100,d0               ;when a timer interrupt happens at the exact same time a trap call is made, two sets of PC and SR are pushed.
        beq     noclash                 ;We need to save the first pair by shifting the SP to the right by 6 bytes
intclash
        add.l   #6,sp
noclash             
        move    (sp),d0
        add.l   #2,sp              
        move.l  d0,tcbsr(a0)
        
        move.l  (sp),d0                 ;pop and store PC
        add.l   #4,sp
        move.l  d0,tcbpc(a0)
        
        move.l  a7,tcba7(a0)            ;store SP 
        
;******************************************************************************
serv                                    ;SERVICE ROUTINES
;******************************************************************************
    move.l id,d0                        ;Check if Timer interrupts
    beq timerserv
    
    move.l id,d0                        ;Check if Syscr
    sub.l #syscr,d0
    beq syscrserv
    
    move.l id,d0                        ;Check if Sysdel
    sub.l #sysdel,d0
    beq sysdelserv
    
    move.l id,d0                        ;Check if syswtmxserv
    sub.l #syswtmx,d0
    beq syswtmxserv

    move.l id,d0                        ;Check if syssgmxserv
    sub.l #syssgmx,d0
    beq syssgmxserv
    
    move.l id,d0                        ;Check if sysinmxserv
    sub.l #sysinmx,d0
    beq sysinmxserv
    
    move.l id,d0                        ;Check if syswttm 
    sub.l #syswttm,d0
    beq syswttmserv

    move.l id,d0                        ;Check if syswtio 
    sub.l #syswtio,d0
    beq syswtioserv
 
timerserv
    move.l  rdytcb,a0
    move.l  tcbnext(a0),a1              ;When timer int occurs, use current tcb's tcbnext field to set a1 (a1 is always used to set rdytcb)

    move.l  tcbwtim(a1),d0              ;if wait field of next tcb is zero then continue to scheduler
    beq sched
    
    
    sub.l   time,d0                     ;if wait field of next tcb not zero AND tcbwtim Equals or is less than Current time then reset tcbwtim and continue to sched
    beq rstwt
    bmi rstwt
    
    move.l  tcbnext(a1),a1              ;next tcb is still waiting so we skip it by scheduling a next next tcb
    bra sched
rstwt    
    move.l  #$00,d0
    move.l  d0,tcbwtim(a1)              ;reset wait time field and continue with the next tcb
    bra sched
    
syswttmserv 
    
    move.l  time,d0
    add.l   d1,d0
    move.l  d0,tcbwtim(a0)		        ;update the tcb with the wait time count
    move.l  tcbnext(a0),a1		        ;switch to next task
    bra sched
    
syscrserv
    move.l  syscrCount, d0
    sub.l   #1, d0
    beq createError
    move.l  d0, syscrCount
    
    move.l  d1, a2
    move.l  UsrStkAdd, a3
    cmpa.l a3,a2
    blt.l addressError
    
    move.l  d2, a2
    move.l  UsrStkAdd, a3
    cmpa.l a3,a2
    blt.l addressError
      
findfreetcb                             ;Create task by finding available tcb and init
    move.l  a0,a0sav
    move.l  #tcblst,a1                  ;subtracting from start of tcb value inorder to correct first tcblist
    sub.l   #tcblen,a1
fftcbloop    
    add.l   #tcblen,a1                  ;search from start of tcblist
    move.l tcbused(a1),d0               ;find next tcb space that is not in use 
    bne fftcbloop                       ;if d0 is 0 it would indicate that tcb is free, else loop again to find free tcb
    
    move.l  tcbnext(a0),a2              ;swap links of current and new TCBs ;NEXT
    move.l  a1,tcbnext(a0)          
    move.l  a2,tcbnext(a1)
    
    move.l  #$00,tcbd0(a1)              ;init registers
    move.l  #$00,tcbd1(a1)       
    move.l  #$00,tcbd2(a1)
    move.l  #$00,tcbd3(a1) 
    move.l  #$00,tcbd4(a1)
    move.l  #$00,tcbd5(a1)       
    move.l  #$00,tcbd6(a1)
    move.l  #$00,tcbd7(a1) 
    move.l  #$00,tcba0(a1)
    move.l  #$00,tcba1(a1)       
    move.l  #$00,tcba2(a1)
    move.l  #$00,tcba3(a1) 
    move.l  #$00,tcba4(a1)
    move.l  #$00,tcba5(a1)       
    move.l  #$00,tcba6(a1)
    

   
    move.l  #%0000000000000000,tcbsr(a1)              ;init SR

    move.l  d1,tcbpc(a1)                ;PC
    move.l  d2,tcba7(a1)                ;store SP 
    
    move.l  #01,tcbused(a1)             ;set used flag 1 to indicate that the tcb is in use
    
    move.l  a0,a1
    
    bra sched
    

sysdelserv
    move.l  syscrCount, d1
    sub.l   sysdelCount, d1
    beq deleteError
    
    move.l sysdelCount, d1
    sub.l #1, d1
    move.l d1, sysdelCount
    move.l  rdytcb,a0
fptcb                                   ;Find Pointing tcb - find the task that points to the requesting task    
    move.l  a0,a1
    move.l  tcbnext(a1),a0      
    move.l  tcbnext(a1),d0
    sub.l   rdytcb,d0                   
    bne fptcb  
    
    move.l  rdytcb,a0
    move.l  tcbnext(a0),a2              ;copy next link of current tcb and put in to pointing TCB
    move.l  a1,tcbnext(a0)          
    move.l  a2,tcbnext(a1)
    
    move.l #00,tcbused(a0)              ;once task deleted the tcb must be marked as unused
    
    move.l  a2,a1               
    bra sched
    

syswtmxserv

    move.l  mutex,d0                     ;check mutex and skip to reready if mutex is free else put task on waitlist
    bne reready
    
    move.l  rdytcb,a0
fptcb1                                  ;Find Pointing tcb - find the task that points to the requesting task    
    move.l  a0,a1
    move.l  tcbnext(a1),a0      
    move.l  tcbnext(a1),d0
    sub.l   rdytcb,d0                   
    bne fptcb1                          ;on exit of this loop, a1 is the tcb that is pointing to the current tcb
    
    move.l  rdytcb,a0                   ;-Swap previous tcb's link and current tcb'link (which takes current tcb off rdylist)
    move.l  tcbnext(a0),a2              ;|
    move.l  tcbnext(a1),tcbnext(a0)     ;|
    move.l  a2,tcbnext(a1)              ;-
    
    ;now we need to keep track of waiting tcb
    
    move.l  wttcb,d0                    ;check if there is anything in the waitlist
    bne     addtowtlst                  ;store next waiting task as element in tcbnext linked list
                                        ;nothing in wait list
    
    move.l  rdytcb,a0                   ;-Swap current tcb's link (which is itself) and waitlist variable (which puts current tcb in waitlist)
    move.l  tcbnext(a0),a2              ;|
    move.l  wttcb,tcbnext(a0)           ;|
    move.l  a2,wttcb                    ;-
    
    move.l  tcbnext(a1),a1              ;previous tcb's link is setup as next task
    bra sched

addtowtlst                              ;(a0-current tcb, a1-pointing tcb, a2-next tcb)
    move.l  wttcb,a2
findtail                                ;finds the element in wiatlist that links to nothing (last element)
    move.l  a2,a3
    move.l  tcbnext(a3),d0
    move.l  tcbnext(a3),a2
    sub.l   #$00000000,d0
    bne     findtail                    ;exiting this loop a3 will have the tail of waitlist
    
    move.l  rdytcb,a0                   ;-Swap last waiting tcb's link and current tcb's link (which puts current tcb at tail of wtlist)
    move.l  tcbnext(a0),a2              ;|
    move.l  tcbnext(a3),tcbnext(a0)     ;|
    move.l  a2,tcbnext(a3)              ;-
    
    move.l  tcbnext(a1),a1              ;previous tcb's link is setup as next task               
    bra sched

reready                                 ;if mutex is 1
    move.l  #00,d0                      ;set mutex to 0
    move.l  d0,mutex
    move.l  rdytcb,a1                   ;task continued 
    
    bra sched
    
syssgmxserv
    move.l  mutex,d0                     ;check mutex, if mutex is free (1) at this point in execution then something has gone wrong
    bne mutexerror
    
    move.l  wttcb,d0
    beq     mtxone                      ;Nothing in waitlist, set mutex to 1 and continue task
                      ;a task is waiting 
       
    move.l  wttcb,a1                    ;wttcb-waiting tcb, a1-next waiting tcb
    
    move.l  tcbnext(a1),a2              ;-Swap head waitlist's link with 2nd waiting's link (head is popped off waitlist, but not yet on ready list)
    move.l  wttcb,tcbnext(a1)           ;|
    move.l  a2,wttcb                    ;-
                                        ;a1-newly ready tcb that is linked to itself
    move.l  rdytcb,a0                   ;-Swap newly ready tcb's link and current tcb's link (which puts newly ready tcb in rdylist)
    move.l  tcbnext(a0),a2              ;|
    move.l  tcbnext(a1),tcbnext(a0)     ;|
    move.l  a2,tcbnext(a1)              ;-
    
                                        ;After returning task to ready list MUTEX IS NOT FREE!
    
    move.l  rdytcb,a1                   ;Continue same task but dont set mutex   free
    bra sched
mtxone 
    move.l  #01,d0                      ;set mutex to 1
    move.l  d0,mutex
    move.l  rdytcb,a1                   ;Continue same task
    bra sched

sysinmxserv
    move.l  d1,mutex
    move.l  rdytcb,a1                   ;Continue same task
    bra sched
    
syswtioserv
    move.l  #$FFFFFFFF,d0
    move.l  d0,tcbwtim(a0)		        ;update the tcb with impossibly high wait time (10+ years if timer is 100ms)
    move.l  tcbnext(a0),a1		        ;switch to next task  
    
    bra sched
    
                    ;Error handlers 
createError                              ;freeze the system incase more than specified tasks created
    move.b  #$3f,seventhdisplay             ;error code 0
    move.b  #$79,$E0000C
    move.b  #$79,$E0000A
    bra createError
    
deleteError                              ;freeze the system incase more than tasks created are tried to be deleted
    move.b  #$06,seventhdisplay         ;error code 1
    move.b  #$79,$E0000C
    move.b  #$79,$E0000A
    bra deleteError
addressError
    move.b  #$5b,seventhdisplay         ;error code 2
    move.b  #$79,$E0000C
    move.b  #$79,$E0000A
    bra addressError
mutexerror
    move.b  #$4f,seventhdisplay         ;error code 3
    move.b  #$79,$E0000C
    move.b  #$79,$E0000A
    bra mutexerror
;*******************************************************************************
sched                                   ;SCHEDULER  
;*******************************************************************************
        
        move.l  a1,rdytcb               ;Move the next tcb to the ready tcb list head

;*******************************************************************************        
disp                                    ;DISPATCHER 
;*******************************************************************************

        move.l  rdytcb,a0               ;A0 ^ new running tcb
        move.l  tcbd1(a0),d1            ;restore registers      
        move.l  tcbd2(a0),d2
        move.l  tcbd3(a0),d3 
        move.l  tcbd4(a0),d4
        move.l  tcbd5(a0),d5       
        move.l  tcbd6(a0),d6
        move.l  tcbd7(a0),d7
        move.l  tcba1(a0),a1       
        move.l  tcba2(a0),a2
        move.l  tcba3(a0),a3 
        move.l  tcba4(a0),a4
        move.l  tcba5(a0),a5       
        move.l  tcba6(a0),a6
        move.l  tcba7(a0),a7

        sub.l   #4,sp                   ;push PC
        move.l  tcbpc(a0),d0            
        move.l  d0,(sp)   

        sub.l   #2,sp           
        move.l  tcbsr(a0),d0            ;push SR

        move    d0,(sp)
        
        move.l  tcbd0(a0),d0            ;restore remaining registers
        move.l  tcba0(a0),a0
        
        
return  rte                             ;return, we can use ret becasue new PC and SR is currently in stack

;*******************************************************************************
                                        ;RTS variables
;*******************************************************************************

tcblst              ds.b    tcblen*ntcblst          ;tcb list
rdytcb              ds.l    1                       ;^ ready tcb list
wttcb               ds.l    1                       ;^ waiting tcb
iowttcb             ds.l    1                       ;^ I/O waiting tcb
a0sav               ds.l    1                       ;A0 temporary save
d0sav               ds.l    1                       ;D0 temporary save
a0sav2              ds.l    1                       ;A0 temporary save for 2nd level interrupt
d0sav2              ds.l    1                       ;D0 temporary save for 2nd level interrupt
sliointcounter      ds.l    1                       ;temp counter for 2nd level interrupt
id                  ds.l    1                       ;function id
time                ds.l    1                       ;system time
running             ds.l    1                       ;shared variable running
mutex               ds.l    1                       ;mutex variable
;*******************************************************************************
                                        ;Internal variables
;*******************************************************************************
ledStatus           ds.l    1                       ;ledstatus variable
flagDelete          ds.l    1                       ;flag to indicate when to deletel a variable
syscrCount          ds.l    1
sysdelCount         ds.l    1
syswtimCount        ds.l    1
UsrCodeAdd          ds.l    1
UsrStkAdd           ds.l    1
;*******************************************************************************
                                        ;USER APPLICATION TASKS
;*******************************************************************************
seventhdisplay equ     $E0000E        
led            equ     $e00010          ;led
sw             equ     $e00014          ;switch

      
    org     usrcode
;*******************************************************************************
*        *EXAMPLE 1
;*******************************************************************************

*    move.b #$3f,$3000 *0
*    move.b #$06,$3001 *1
*    move.b #$5b,$3002 ;2
*    move.b #$4f,$3003 ;3
*    move.b #$66,$3004 ;4
*    move.b #$6d,$3005 ;5
*    move.b #$7d,$3006 ;6
*    move.b #$07,$3007 ;7
*    move.b #$7f,$3008 ;8
*    move.b #$67,$3009 ;9
*    move.b #$77,$300A ;A
*    move.b #$7c,$300b ;b
*    move.b #$39,$300C ;C
*    move.b #$5e,$300D ;d
*    move.b #$79,$300E ;E
*    move.b #$71,$300F ;F
*    move.b #$80,$3010 ;.
*    
*    move.b  #$00,seventhdisplay         ;Empty the 7seg displays
*    move.b  #$00,$E0000C
*    move.b  #$00,$E0000A
*    move.b  #$00,$E00008
*    move.b  #$00,$E00006
*    move.b  #$00,$E00004
*    move.b  #$00,$E00002
*    move.b  #$00,$E00000
*    
*    
*
*t0:                                       ;TASK 0
*        move.l  #$00,running              ;init running flag
*        move.l  #$3000,a2
*        move.l  #$3000,a3
*        move.l  #10, d6
*        
*        move.b  (a2)+,seventhdisplay
*        move.b  (a3),$E0000C
*        
*        move.l  #syscr,d0                 ;start task 1 - to check button press and toggle running flag
*        move.l  #t1,d1
*        move.l  #$5000,d2
*
*        trap    #sys        
*                                          ;repeat
*t00:    
*        move.l running, d4
*        sub #$1,d4
*        beq incrementDisplay
*        bne t00
*        
*
*incrementDisplay
*        move.b (a2),d5    
*        and #$00FF,d5                     ;clear upper byte of d0
*        sub #$77,d5                       ;check untill 9 after 9 reset to 0
*        beq reset1s     
*
*        move.b (a3),d5    
*        and #$00FF,d5                     ;clear upper byte of d0
*        sub #$7d,d5                       ;check untill 9 after 9 reset to 0
*        beq reset10s    
*        
*        move.b (a2)+,seventhdisplay
*        move.b (a3),$E0000C
*        
*        move.l  #syswttm,d0                 ;wait timer
*        move.l  #10,d1                      ;wait 10 ints
*        trap    #sys  
* 
*        bra     t00
*        
*
*     
*reset1s:  move    #$3000,a2                    ;point to starting value of to be displayed on 7 seven segement display
*        add.l   #$1,a3
*        bra     incrementDisplay
*
*reset10s:  move    #$3000,a3                    ;point to starting value of to be displayed on 7 seven segement display
*        bra     incrementDisplay
*    
*    ;Data starts at $3000
*    
*    
*    org     $4000
*t1:                                      
*        
*check 
*        move.b $E00014,d0
*        
*        and #$01,d0
*        sub #$01,d0
*        beq check 
*        bne pressed
*          
*pressed 
*        move.b $E00014,d0
*        and #$01,d0
*        sub #$01,d0
*        bne pressed
*
*
*        move.l running,d3
*        eor #01, d3                       ;check for switch status
*        move.l d3, running                ;update running flag
*
*        bra     t1
        
;*******************************************************************************        
        *END OF EXAMPLE 1
;*******************************************************************************   

    
;*******************************************************************************       
         *MUTEX EXAMPLE 2
;******************************************************************************* 

*        org usrcode
*
*        
*        
*        move.b #$3f,$3000 *0
*        move.b #$06,$3001 *1
*        move.b #$5b,$3002 ;2
*        move.b #$4f,$3003 ;3
*        move.b #$66,$3004 ;4
*        move.b #$6d,$3005 ;5
*        move.b #$7d,$3006 ;6
*        move.b #$07,$3007 ;7
*        move.b #$7f,$3008 ;8
*        move.b #$67,$3009 ;9
*        
*        move.b  #$00,$E0000E         ;Empty the 7seg displays
*        move.b  #$00,$E0000C
*        move.b  #$00,$E0000A
*        move.b  #$00,$E00008
*        move.b  #$00,$E00006
*        move.b  #$00,$E00004
*        move.b  #$00,$E00002
*        move.b  #$00,$E00000
*        
*
*Task0
*        move.l  #$3000,a2                   ;store address of 7seg display bytes
*        
*        move.l  #0,d0                       ;init A B C and D
*        move.l  d0,a
*        move.l  d0,b
*        move.l  d0,c
*        move.l  d0,d
*        
*        move.l  #syscr,d0                   ;start task 1
*        move.l  #Task1,d1                   ;Task at address $4000
*        move.l  #$5000,d2                   ;SP for Task at $5000
*        trap    #sys 
*        
*        move.l  #syscr,d0                   ;start task 2
*        move.l  #Task2,d1                   ;Task at address $5000
*        move.l  #$6000,d2                   ;SP for Task at address $6000
*        trap    #sys 
*    
*        move.l  #sysinmx,d0                 ;init mutex
*        move.l  #1,d1
*        trap    #sys 
*        
*Task00
*        
*        move.l  a,d0
*        add.l   #$01,d0
*        move.l  d0,a
*        
*        move.l  #syswtmx,d0                 ;wait mutex
*        trap    #sys 
*    
*        move.l  d,d0
*        add.l   #$01,d0
*        move.l  d0,d
*        
*        move.l  #syssgmx,d0                 ;Signal mutex
*        trap    #sys
*        
*        move.l  a,d0
*        move.l  b,d1
*        move.l  c,d2
*        move.l  d,d3
*
*        
*        add.l   d1,d0                          ;Compute A + B + C - D
*        add.l   d2,d0
*        sub.l   d3,d0
*            
*        move.b  0(a2,d0.w),$E0000E             ;Display difference in RH 7 seg
*        
*        sub.l   #$5,d0
*        bmi     Task00
*        
*        bra Task00
*
*        org $4000
*Task1
*        move.l  b,d0
*        add.l   #$01,d0
*        move.l  d0,b
*        
*        move.l  #syswtmx,d0                 ;wait mutex
*        trap    #sys         
*    
*        move.l  d,d0
*        add.l   #$01,d0
*        move.l  d0,d
*        
*        move.l  #syssgmx,d0                 ;Signal mutex
*        trap    #sys
*        
*        
*        bra Task1
*        org $5000
*Task2
*        move.l  c,d0
*        add.l   #$01,d0
*        move.l  d0,c
*        
*        move.l  #syswtmx,d0                 ;wait mutex
*        trap    #sys         
*    
*        move.l  d,d0
*        add.l   #$01,d0
*        move.l  d0,d
*        
*        move.l  #syssgmx,d0                 ;Signal mutex
*        trap    #sys
*        
*        bra Task2
*        
*        
*        ;Data
*a   dc.l    0
*b   dc.l    0
*c   dc.l    0   
*d   dc.l    0 

;*******************************************************************************        
        *END OF MUTEX EXAMPLE 2
;*******************************************************************************


;*******************************************************************************  
*        *I/O interrupt EXAMPLE
;*******************************************************************************

*        org usrcode
*
*led     equ     $e00010         ;led
*sw      equ     $e00014         ;switch
*
*Task0                             
*        move.l  #syscr,d0       ;start task 1
*        move.l  #Task1,d1
*        move.l  #$4000,d2
*        trap    #sys        
*                                ;repeat
*Task00
*        move.l  #$01,d1         ;  set led 0
*        move.b  d1,led
*          
*        
*        bra     Task00
*        
*Task1                               
*                               
*        move.l  #$02,d0         ;  set led 1
*        move.b  d0,led
*        
*        move.l #$0000FFFF,d1
*delay1
*        move.b  d0,led
*        sub.l   #01,d1        
*        bne     delay1
*        
*        move.l  #syswtio,d0       ;wait for I/O before proceeding
*        trap    #sys 
*        
*        bra     Task1

;*******************************************************************************        
*        *End of I/O interrupt EXAMPLE
;*******************************************************************************


;*******************************************************************************       
*        *EXAMPLE 4
;*******************************************************************************
*
*        org usrcode
*
*        move.b  #$00,seventhdisplay    ;Empty the 7seg displays
*        move.b  #$00,$E0000C
*        move.b  #$00,$E0000A
*        move.b  #$00,$E00008
*        move.b  #$00,$E00006
*        move.b  #$00,$E00004
*        move.b  #$00,$E00002
*        move.b  #$00,$E00000
*        
*        move.l  #00, ledStatus     
*        move.l  #00, flagDelete
*        move.b  #00,led
*    
*Task0   
*              
*        move.l  #syscr,d0       ;start task 7
*        move.l  #Task7,d1 
*        move.l  #$5000,d2
*        trap    #sys  
*          
*        move.l  #syscr,d0       ;start task 6
*        move.l  #Task66,d1  
*        move.l  #$5504,d2
*        trap    #sys  
* 
*        
*        move.l  #syscr,d0       ;start task 5
*        move.l  #Task55,d1  
*        move.l  #$5512,d2
*        trap    #sys 
*        
*        move.l  #syscr,d0      ;start task 4
*        move.l  #Task44,d1  
*        move.l  #$5516,d2
*        trap    #sys
*        
*        move.l  #syscr,d0       ;start task 3
*        move.l  #Task33,d1
*        move.l  #$5520,d2
*
*        trap    #sys
*        
*        move.l  #syscr,d0       ;start task 2
*        move.l  #Task22,d1
*        move.l  #$5524,d2
*        trap    #sys  
*        
*        move.l  #syscr,d0       ;start task 1
*        move.l  #Task11,d1
*        move.l  #$5528,d2
*        trap    #sys
*
*       
*        move.l  #2,d2                        
*Task00
*        move.l (flagDelete),d4
*        sub.l   #01, d4
*        beq     delLink00
*        
*        move.l  (ledStatus),d3 
*        sub.l   #1,d2
*        beq     switchoff00 
*        rol.l   #1,d3
*        or.l    #1,d3
*        move.l d3, (ledStatus)
*        move.l #$0000FFFF,d1
*delay0
*        sub.l   #01,d1        
*        bne     delay0 
*        
*        move.b  d3,led
*
*        bra     Task00
*
*switchoff00
*        move.l (flagDelete),d4
*        sub.l   #01, d4
*        beq     delLink00
*        bra     switchoff00
*        
*delLink00
*        move.l (ledStatus),d3
*        lsl.l  #01, d3
*        move.l d3, (ledStatus)
*        move.b  d3,led
*        
*      
*        move.l  #sysdel,d0       ;delete task 0
*        trap    #sys 
*
*        org $4000        
*          
*Task11                                                        
*        move.l  #2,d2
*Task1   
*        move.l (flagDelete),d4
*        sub.l   #01, d4
*        beq     delLink11
*        
*        move.l  ledStatus,d3  
*        sub.l   #1,d2
*        beq     switchoff11 
*        rol.l   #1,d3
*        or.l    #1,d3
*        move.l d3, (ledStatus) 
*        move.b  d3,led
*
*        bra     Task1
*        
*switchoff11
*        move.l (flagDelete),d4
*        sub.l   #01, d4
*        beq     delLink11
*        bra     switchoff11     
*
*delLink11
*        move.l (ledStatus),d3
*        lsl.l  #01, d3
*        move.l d3, (ledStatus)
*        move.b  d3,led
*        
*        move.l #$00004FFF,d1
*delay1
*        sub.l   #01,d1        
*        bne     delay1
*        
*        move.l  #sysdel,d0       ;delete task 1
*        trap    #sys    
*        
*Task22  
*        move.l  #2,d2                                               
*Task2   
*        move.l (flagDelete),d4
*        sub.l   #01, d4
*        beq     delLink22
*        
*        move.l  (ledStatus),d3  
*        sub.l   #1,d2
*        beq     switchoff22 
*        rol.l   #1,d3
*        or.l    #1,d3
*
*        move.l d3, (ledStatus) 
*        move.b  d3,led
*       
*        bra     Task2
*
*switchoff22
*        move.l (flagDelete),d4
*        sub.l   #01, d4
*        beq     delLink22
*        bra     switchoff22
*delLink22
*        move.l (ledStatus),d3
*        lsl.l  #01, d3
*        move.l d3, (ledStatus)
*        move.b  d3,led
*        
*        move.l #$00004FFF,d1
*delay2
*        sub.l   #01,d1        
*        bne     delay2
*        
*        move.l  #sysdel,d0       ;delete task 2
*        trap    #sys     
*       
*Task33                              
*        move.l  #2,d2                       
*Task3   
*        move.l (flagDelete),d4
*        sub.l   #01, d4
*        beq     delLink33
*        
*        move.l  ledStatus,d3  
*        sub.l   #1,d2
*        beq     switchoff33 
*        rol.l   #1,d3
*        or.l    #1,d3
*        move.l d3, (ledStatus) 
*        move.b  d3,led
*       
*        bra     Task3
*        
*switchoff33
*        move.l (flagDelete),d4
*        sub.l   #01, d4
*        beq     delLink22
*        bra     switchoff33
*delLink33
*        move.l (ledStatus),d3
*        lsl.l  #01, d3
*        move.l d3, (ledStatus)
*        move.b  d3,led
*        
*        move.l #$00004FFF,d1
*delay3
*        sub.l   #01,d1        
*        bne     delay3
*        
*        move.l  #sysdel,d0       ;delete task 3
*        trap    #sys      
*        
*Task44                               
*        move.l  #2,d2                       
*Task4   
*        move.l (flagDelete),d4
*        sub.l   #01, d4
*        beq     delLink44
*        
*        move.l  ledStatus,d3  
*        sub.l   #1,d2
*        beq     switchoff44 
*        rol.l   #1,d3
*        or.l    #1,d3
*        move.l d3, (ledStatus) 
*        move.b  d3,led 
*      
*        bra     Task4
*        
*switchoff44
*        move.l (flagDelete),d4
*        sub.l   #01, d4
*        beq     delLink22
*        bra     switchoff44   
*delLink44
*        move.l (ledStatus),d3
*        lsl.l  #01, d3
*        move.l d3, (ledStatus)
*        move.b  d3,led
*        
*        move.l #$00004FFF,d1
*delay4
*        sub.l   #01,d1        
*        bne     delay4
*Task55
*        move.l  #2,d2
*Task5
*        move.l (flagDelete),d4
*        sub.l   #01, d4
*        beq     delLink44
*        
*        move.l  ledStatus,d3  
*        sub.l   #1,d2
*        beq     switchoff55 
*        rol.l   #1,d3
*        or.l    #1,d3
*        move.l d3, (ledStatus) 
*        move.b  d3,led      
*      
*        bra     Task5
*        
*switchoff55
*        move.l (flagDelete),d4
*        sub.l   #01, d4
*        beq     delLink22      
*        bra     switchoff55
*delLink55
*        move.l (ledStatus),d3
*        lsl.l  #01, d3
*        move.l d3, (ledStatus)
*        move.b  d3,led
*        
*        move.l #$00004FFF,d1
*delay5
*        sub.l   #01,d1        
*        bne     delay5
*        
*        move.l  #sysdel,d0       ;delete task 5 
*        trap    #sys           
*   
*Task66                               
*        move.l   #2,d2                       
*Task6   
*        move.l (flagDelete),d4
*        sub.l   #01, d4
*        beq     delLink66  
*        
*        move.l  ledStatus,d3  
*        sub.l   #1,d2
*        beq     switchoff66 
*        rol.l   #1,d3
*        or.l    #1,d3
*        move.l d3, (ledStatus) 
*        move.b  d3,led   
*       
*        bra     Task6 
*        
*switchoff66
*        move.l (flagDelete),d4
*        sub.l   #01, d4
*        beq     delLink22
*        bra     switchoff66   
*delLink66
*        move.l (ledStatus),d3
*        lsl.l  #01, d3
*        move.l d3, (ledStatus)
*        move.b  d3,led
*        
*        move.l #$00004FFF,d1
*delay6
*        sub.l   #01,d1        
*        bne     delay6
*        
*        move.l  #sysdel,d0       ;delete task 6
*        trap    #sys     
*       
*Task7   
*        move.l   #2,d2                                              
*Task77  
*        move.l (flagDelete),d4
*        sub.l   #01, d4
*        beq     delLink77
*  
*        move.l  ledStatus,d3  
*        sub.l   #1,d2
*        beq     switchoff77 
*        rol.l   #1,d3
*        or.l    #1,d3
*        move.l d3, (ledStatus) 
*        move.b  d3,led
*     
*        bra     Task77
*        
*switchoff77
*        move.l #01, (flagDelete)
*        bra     switchoff77   
*delLink77
*        move.l (ledStatus),d3
*        lsl.l  #01, d3
*        move.l d3, (ledStatus)
*        move.b  d3,led
*        bra switchoff77

;*******************************************************************************        
*        *END OF EXAMPLE 4
;*******************************************************************************


;*******************************************************************************
*        *EXAMPLE 5
;*******************************************************************************

*        org usrcode
*
*        move.b  #$00,seventhdisplay         ;Empty the 7seg displays
*        move.b  #$00,$E0000C
*        move.b  #$00,$E0000A
*        move.b  #$00,$E00008
*        move.b  #$00,$E00006
*        move.b  #$00,$E00004
*        move.b  #$00,$E00002
*        move.b  #$00,$E00000
*       
*Task0                             
*        move.l  #syscr,d0       ;start task 1
*        move.l  #Task1,d1
*        move.l  #$5000,d2
*        trap    #sys        
*                                ;repeat
*Task00
*        move.l  #$01,d1         ;  set led 0
*        move.b  d1,led
*          
**	    move.l  #syswttm,d0                 ;wait timer
**        move.l  #10,d1                      ;wait 10 ints
**        trap    #sys 
*        
*        bra     Task00
*        
*        org $4000
*Task1                               
*                               
*        move.l  #$02,d0         ;  set led 1
*        move.b  d0,led
*        
*        ;move.l  #syswttm,d0                 ;wait timer
*        ;move.l  #10,d1                      ;wait 10 ints
*        
*        ;trap    #sys  
*        
*        move.l #$0000FFFF,d1
*delay
*        move.b  d0,led
*        sub.l   #01,d1        
*        bne     delay
*        move.l  #sysdel,d0       ;delete task 1
*        trap    #sys 
*       
*        bra     Task1

   
;*******************************************************************************        
*        *END OF EXAMPLE 5
;*******************************************************************************        
        END    res  













































































































































*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
