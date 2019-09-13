

;==========================
; SUB-PROCESSES
;==========================

; land banking relates to interest rate, high interest rate, parke the money on bank. 
; High increase in land that surpase the interest rate, send the money for land banking
; raymond tse (housing price, land supply, and revenue from land sales)

;to land-expansion
;  ask developers
;  [
;  
;  let find-expand-patches min-n-of 15 patches in-radius ( field-assessment-radius / .3) with
;                                                      [   field-developed?  = "false" and
;                                                          field-land-value != -9999 and
;                                                          field-land-value > 0 ] 
;                                                       [  field-expansion-cost ]
;                                                  
;  ask find-expand-patches 
;  [ 
;    set field-assessed? "true" 
;    set field-visited?  "true"
;    set field-developed?  "true"
;    set field-land-use 50
;    set pcolor black
;  ]
;  
;  set developer-capital ( developer-capital - ( sum [field-expansion-cost] of find-expand-patches ) )
;  set developer-capital precision developer-capital 1
;   ]
;  ; something like , check surrounding cell
;  ; calculate the profit
;  ; acquire, and convert
;end
;
;to land-construction
;  ; something like ifelse
;  ; if true , convert the land
;  ; else, land banking?
;end
;
;to field-threshold-profit
;  ; i dont know
;  ; but seems important
;end


;==========================
; SUB-PROCESSES
;==========================

to land-select
  ; something like , list  5 visited sites 
  ; select one of the most profitable
end


to land-stay 
  while  [ developer-count-down > 0 ]
  [
    let x-cor-stay [xcor] of myself
    let y-cor-stay [ycor] of myself
    setxy  x-cor-stay y-cor-stay
    set developer-count-down (developer-count-down - 1)   ;decrement-timer
  ]
end

; land banking relates to interest rate, high interest rate, parke the money on bank. 
; High increase in land that surpase the interest rate, send the money for land banking
; raymond tse (housing price, land supply, and revenue from land sales)




;==========================
; UPDATE
;==========================

to update-land-cover
  ask developers 
  [ if (developer-type = "small") and (developer-mode = "developing")
    [
      ask developer-patches
      [
        set field-assessed?    "true" 
        set field-visited?     "true"
        set field-developed?   "true"   
        set field-land-use      50
        set pcolor              black
      ]
      
;      let patches-neighbour patches in-radius ( 3 / .3) with [ field-land-value-pxl > 0 ]  ; field-assessment-radius
;      let patches-neighbour-target min-n-of   (developer-target-size / 9) patches-neighbour [distance myself]  
;      
;      ask patches-neighbour-target
;      [
;        set field-assessed?    "true" 
;        set field-visited?     "true"
;        set field-developed?   "true"   
;        set field-land-use      50
;        set pcolor              black
;      ] 
    ]
    
    if (developer-type = "large") and (developer-mode = "developing")
    [
      ask developer-patches
      [
        set field-assessed?    "true" 
        set field-visited?     "true"
        set field-developed?   "true"   
        set field-land-use      51
        set pcolor              black
      ]
      
;      let patches-neighbour patches in-radius ( 3 / .3) with [ field-land-value-pxl > 0 ]  ; field-assessment-radius
;      let patches-neighbour-target min-n-of   (developer-target-size / 9) patches-neighbour [distance myself]  
;      
;      ask patches-neighbour-target
;      [
;        set field-assessed?    "true" 
;        set field-visited?     "true"
;        set field-developed?   "true"   
;        set field-land-use      51
;        set pcolor              black
;      ] 
    ]
  ]
     
end


to update-land-value             ; patch procedure after the "land stay" loop
  ask patches in-radius 12 
  [
    set field-dist-new-urban   distance myself 
    set field-land-value-pxl   (land-value-increased * field-land-value-pxl)
  ]
;  ask patches             [ set field-dist-new-urban min [distance myself] of patches with [field-land-use = 55]]
;  ask patches in-radius 12 [ set field-land-value-pxl ( field-land-value-pxl * 1.10 ) ]
;  ask patches in-radius 9  [ set field-land-value-pxl ( field-land-value-pxl * 1.30 ) ]
;  ask patches in-radius 6  [ set field-land-value-pxl ( field-land-value-pxl * 1.50 ) ]
;  ask patches in-radius 3  [ set field-land-value-pxl ( field-land-value-pxl * 1.90 ) ]
;  ask patch-here           [ set field-land-value-pxl ( field-land-value-pxl * 2.00 ) ]
;  if field-land-value-pxl > 3000   [ set field-land-value-pxl 3000 ] 
end


;==========================
; To REPORT
;==========================

;to-report field-want-to-buy?
;  ; should add conditional
;  ; if developer large
;  report  field-total-cost <= developer-capital
;end
