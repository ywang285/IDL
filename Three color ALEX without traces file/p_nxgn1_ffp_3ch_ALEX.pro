; semi-automated routine to find all potential peaks
; in the current image. its sort of implicit that the
; image is 512 x 512...
;
; hazen 1/99
;
; modified to look in the "left" channel for peaks, then
; figure out where the peak should be in the "right" channel,
; and then evaluates both spots to see that they are not to
; close to other spots or otherwise ugly
;
; Hazen 1/99
;
; modified to also to the inverse of the previous comment
; i.e. "right" to "left". also, loads mapping coefficients
; so you have to run calc_mapping3 first.
;
; Hazen 2/99
;
; modified to use the same background subtraction routine
; as findpeak2
;
; Hazen 3/99
;
; modified to map the right half of the screen onto the
; left half of the screen to avoid biases in the histograms
; against peaks that have an intermediate FRET value, i.e.
; half of their intensity is in the left channel and half
; is in the right channel. image must be 512x512.
;
; Hazen 11/99
;
; modified to allow for and find half-integer peak centroid positions
;
; Hazen 11/99
;
; made into a procedure to work with batch analysis
;
; Hazen 3/00
;
; modified to work for TJ
;
; Hazen 3/00
;

pro p_nxgn1_ffp_3ch_ALEX, run

loadct, 5

COMMON colors, R_ORIG, G_ORIG, B_ORIG, R_CURR, G_CURR, B_CURR

circle = bytarr(11,11)

;circle(*,0) = [ 0,0,0,0,0,0,0,0,0,0,0]
;circle(*,1) = [ 0,0,0,0,1,1,1,0,0,0,0]
;circle(*,2) = [ 0,0,0,1,0,0,0,1,0,0,0]
;circle(*,3) = [ 0,0,1,0,0,0,0,0,1,0,0]
;circle(*,4) = [ 0,1,0,0,0,0,0,0,0,1,0]
;circle(*,5) = [ 0,1,0,0,0,0,0,0,0,1,0]
;circle(*,6) = [ 0,1,0,0,0,0,0,0,0,1,0]
;circle(*,7) = [ 0,0,1,0,0,0,0,0,1,0,0]
;circle(*,8) = [ 0,0,0,1,0,0,0,1,0,0,0]
;circle(*,9) = [ 0,0,0,0,1,1,1,0,0,0,0]
;circle(*,10)= [ 0,0,0,0,0,0,0,0,0,0,0]

circle(*,0) = [ 0,0,0,0,0,0,0,0,0,0,0]
circle(*,1) = [ 0,0,0,0,0,0,0,0,0,0,0]
circle(*,2) = [ 0,0,0,0,1,1,1,0,0,0,0]
circle(*,3) = [ 0,0,0,1,0,0,0,1,0,0,0]
circle(*,4) = [ 0,0,1,0,0,0,0,0,1,0,0]
circle(*,5) = [ 0,0,1,0,0,0,0,0,1,0,0]
circle(*,6) = [ 0,0,1,0,0,0,0,0,1,0,0]
circle(*,7) = [ 0,0,0,1,0,0,0,1,0,0,0]
circle(*,8) = [ 0,0,0,0,1,1,1,0,0,0,0]
circle(*,9) = [ 0,0,0,0,0,0,0,0,0,0,0]
circle(*,10)= [ 0,0,0,0,0,0,0,0,0,0,0]

; generate gaussian peaks

g_peaks = fltarr(3,3,7,7)

for k = 0, 2 do begin
    for l = 0, 2 do begin
       offx = 0.5*float(k-1)
       offy = 0.5*float(l-1)
       for i = 0, 6 do begin
         for j = 0, 6 do begin
          dist = 0.4 * ((float(i)-3.0+offx)^2 + (float(j)-3.0+offy)^2)
          g_peaks(k,l,i,j) = exp(-dist)
         endfor
       endfor
    endfor
endfor

; initialize variables

film_x = fix(1)
film_y = fix(1)
fr_no  = fix(1)



; input film

close, 1          ; make sure unit 1 is closed

openr, 1, run + ".pma"

; figure out size + allocate appropriately

result = FSTAT(1)
readu, 1, film_x
readu, 1, film_y
film_l = long(long(result.SIZE-4)/(long(film_x)*long(film_y)))

print, "film x,y,l : ", film_x,film_y,film_l

frame   = bytarr(film_x,film_y)
ave_arr = fltarr(film_x,film_y)

ffilm_l=5 ; frank, ffilm_l can be as short as 5

openr, 2, run + "_ave.tif", ERROR = err
if err eq 0 then begin
    close, 2
    close, 1
    frame = read_tiff(run + "_ave.tif")
endif else begin
    close, 2

	;for j = 0, film_l - 9 do begin
    ;	readu, 1, frame
    ;endfor

    for j = 0, ffilm_l - 1 do begin
       if((j mod 5) eq 0) then print, j, film_l
       readu, 1, frame
       ave_arr = ave_arr + frame
    endfor
    close, 1
    ave_arr = ave_arr/float(ffilm_l)

    frame = byte(ave_arr)

    WRITE_TIFF, run + "_ave.tif", frame, 1, RED = R_ORIG, GREEN = G_ORIG, BLUE = B_ORIG
endelse

; subtracts background

temp1 = frame
temp1 = smooth(temp1,2,/EDGE_TRUNCATE)

aves = fltarr(film_x/16,film_y/16)

for i = 8, film_x, 16 do begin
    for j = 8, film_y, 16 do begin
       aves((i-8)/16,(j-8)/16) = min(temp1(i-8:i+7,j-8:j+7))
    endfor
endfor

aves = rebin(aves,film_x,film_y)
aves = smooth(aves,30,/EDGE_TRUNCATE)

temp1 = frame - (byte(aves) - 10)



; generate red background using last 20-11 red frames when the red laser is on
openr, 1, run + ".pma"
frame1   = bytarr(film_x,film_y)
ave_arr1 = fltarr(film_x,film_y)

readu, 1, film_x
readu, 1, film_y
for j = 0, film_l - 21 do begin
	readu, 1, frame1
endfor

for j = 0, ffilm_l - 1 do begin
   if((j mod 5) eq 0) then print, j, film_l
   readu, 1, frame1
   ave_arr1 = ave_arr1 + frame1
endfor
close, 1
ave_arr1 = ave_arr1/float(ffilm_l)

frame1 = byte(ave_arr1)

temp11 = frame1
temp11 = smooth(temp11,2,/EDGE_TRUNCATE)

aves1 = fltarr(film_x/16,film_y/16)

for i = 8, film_x, 16 do begin
    for j = 8, film_y, 16 do begin
       aves1((i-8)/16,(j-8)/16) = min(temp11(i-8:i+7,j-8:j+7))
    endfor
endfor

aves1 = rebin(aves1,film_x,film_y)
aves1 = smooth(aves1,30,/EDGE_TRUNCATE)

; generate green background using last 10-1 green frames when the green laser is on
openr, 1, run + ".pma"
frame2   = bytarr(film_x,film_y)
ave_arr2 = fltarr(film_x,film_y)

readu, 1, film_x
readu, 1, film_y
for j = 0, film_l - 11 do begin
	readu, 1, frame2
endfor

for j = 0, ffilm_l - 1 do begin
   if((j mod 5) eq 0) then print, j, film_l
   readu, 1, frame2
   ave_arr2 = ave_arr2 + frame2
endfor
close, 1
ave_arr2 = ave_arr2/float(ffilm_l)

frame2 = byte(ave_arr2)

temp12 = frame2
temp12 = smooth(temp12,2,/EDGE_TRUNCATE)

aves2 = fltarr(film_x/16,film_y/16)

for i = 8, film_x, 16 do begin
    for j = 8, film_y, 16 do begin
       aves2((i-8)/16,(j-8)/16) = min(temp12(i-8:i+7,j-8:j+7))
    endfor
endfor

aves2 = rebin(aves2,film_x,film_y)
aves2 = smooth(aves2,30,/EDGE_TRUNCATE)

; WRITE_TIFF, run + "_ave_bsl.tif", aves1, 1, RED = R_ORIG, GREEN = G_ORIG, BLUE = B_ORIG

; open file that contains how the channels map onto each other

P = fltarr(4,4)
Q = fltarr(4,4)
P2 = fltarr(4,4)
Q2 = fltarr(4,4)
foo = float(1)

print, ""
openr, 1, "D:\tir data\rough_35.map" ;

readf, 1, P
readf, 1, Q
close, 1

print, ""
openr, 1, "D:\tir data\rough_37.map" ;

readf, 1, P2
readf, 1, Q2
close, 1

; and map the right half of the screen onto the left half of the screen
; temp1 is background subtracted
Cy7 = temp1(342:511,0:511)
Cy5 = temp1(171:340,0:511)
Cy3 = temp1(0:169,0:511)

Cy5 = POLY_2D(Cy5, P, Q, 2)
Cy7 = POLY_2D(Cy7, P2, Q2, 2)


combined = Cy7

; thresholds the image for peak finding purposes

temp2 = combined
med = float(median(combined))
std = 8

for i = 0, 169 do begin
    for j = 0, film_y - 1 do begin
       if temp2(i,j) lt byte(med + std) then temp2(i,j) = 0
    endfor
endfor

; frame is not background subtracted
window, 0, xsize = 512, ysize = 512
tv, frame

; temp2 was combined filtered
window, 1, xsize = 170, ysize = 512
tv, combined

; find the peaks

temp3 = frame
temp4 = combined

good = fltarr(2,4000)
back = fltarr(4000)
back2 = fltarr(4000)
foob = bytarr(7,7)
diff = fltarr(3,3)

no_good = 0

for i = 15, 156 do begin
    for j = 15, 486 do begin
       if temp2(i,j) gt 0 then begin

         ; find the nearest maxima

         foob = temp2(i-3:i+3,j-3:j+3)
         z = max(foob,foo)
         y = foo / 7 - 3
         x = foo mod 7 - 3

         ; only analyze peaks in current column,
         ; and not near edge of area analyzed

         if x eq 0 then begin
          if y eq 0 then begin
              y = y + j
              x = x + i

              ; check if its a good peak
              ; i.e. surrounding points below 1 stdev

              quality = 1
              for k = -5, 5 do begin
                 for l = -5, 5 do begin
                   if circle(k+5,l+5) gt 0 then begin
                    if combined(x+k,y+l) gt byte(med + 0.45 * float(z)) then quality = 0
                   endif
                 endfor
              endfor

              if quality eq 1 then begin

                 ; draw where peak was found on screen

                 for k = -5, 5 do begin
                   for l = -5, 5 do begin
                    if circle(k+5,l+5) gt 0 then begin
                        temp3(x+k,y+l) = 90
                        temp4(x+k,y+l) = 90
                    endif
                   endfor
                 endfor

                 ; compute difference between peak and gaussian peak

                 cur_best = 10000.0
                 for k = 0, 2 do begin
                   for l = 0, 2 do begin
                    diff(k,l) = total(abs((float(z) - aves(x,y)) * g_peaks(k,l,*,*) - (float(temp1(x-3:x+3,y-3:y+3)) - aves(x,y))))
                    if diff(k,l) lt cur_best then begin
                        best_x = k
                        best_y = l
                        cur_best = diff(k,l)
                    endif
                   endfor
                 endfor

                 flt_x = float(x) - 0.5*float(best_x-1)
                 flt_y = float(y) - 0.5*float(best_y-1)

                 ; calculate and draw location of companion peak

                 xf = 171.0
                 yf = 0.0
                 for k = 0, 3 do begin
                   for l = 0, 3 do begin
                    xf = xf + P(k,l) * float(flt_x^l) * float(flt_y^k)
                    yf = yf + Q(k,l) * float(flt_x^l) * float(flt_y^k)
                   endfor
                 endfor

                 int_xf = round(xf)
                 int_yf = round(yf)

                 for k = -5, 5 do begin
                   for l = -5, 5 do begin
                    if circle(k+5,l+5) gt 0 then begin
                     if (int_xf+k le 511) and (int_yf+l le 511) then begin
                        temp3(int_xf+k,int_yf+l) = 90
                     endif
                    endif
                   endfor
                 endfor

                 xf = float(round(2.0 * xf)) * 0.5
                 yf = float(round(2.0 * yf)) * 0.5

				 xf2 = 342.0
                 yf2 = 0.0
                 for k = 0, 3 do begin
                   for l = 0, 3 do begin
                    xf2 = xf2 + P2(k,l) * float(flt_x^l) * float(flt_y^k)
                    yf2 = yf2 + Q2(k,l) * float(flt_x^l) * float(flt_y^k)
                   endfor
                 endfor

                 int_xf2 = round(xf2)
                 int_yf2 = round(yf2)

                 for k = -5, 5 do begin
                   for l = -5, 5 do begin
                    if circle(k+5,l+5) gt 0 then begin
                     if (int_xf2+k le 511) and (int_yf2+l le 511) then begin
                        temp3(int_xf2+k,int_yf2+l) = 90
                     endif
                    endif
                   endfor
                 endfor

                 xf2 = float(round(2.0 * xf2)) * 0.5
                 yf2 = float(round(2.0 * yf2)) * 0.5

                 good(0,no_good) = flt_x
                 good(1,no_good) = flt_y
                 back(no_good) = aves2(x,y) ;frank for Cy3 background subtraction
                 back2(no_good) = aves1(x,y) ;frank for Cy3 background subtraction
                 no_good = no_good + 1
                 good(0,no_good) = xf
                 good(1,no_good) = yf
                 back(no_good) = aves2(int_xf,int_yf) ;frank for Cy5 background subtraction
                 back2(no_good) = aves1(int_xf,int_yf) ;frank for Cy5 background subtraction
                 no_good = no_good + 1
                 good(0,no_good) = xf2
                 good(1,no_good) = yf2
                 back(no_good) = aves2(int_xf2,int_yf2) ;frank for Cy7 background subtraction
                 back2(no_good) = aves1(int_xf2,int_yf2) ;frank for Cy7 background subtraction
                 no_good = no_good + 1
              endif
          endif
         endif
       endif
    endfor
endfor

wset, 0
tv, temp3
wset, 1
tv, temp4

WRITE_TIFF, run + "_selected.tif", temp3, 1, RED = R_ORIG, GREEN = G_ORIG, BLUE = B_ORIG

print, "there were ", no_good, "good peaks"

close, 1
openw, 1, run + ".pks"
for i = 0, no_good - 1 do begin
    printf, 1, i+1, good(0,i),good(1,i),back(i),back2(i)
endfor

close, 1
end