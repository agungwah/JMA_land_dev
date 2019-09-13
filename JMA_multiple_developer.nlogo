; Jabodetabek (JMA) urban model 
; cell size 300m x 300 m = 90000m2 = 9ha
; -- the structure of coding was adapted from Valbuena effect of farmer decision on the landscape of Dutch rural region
; -- created by Agung Wahyudi
; -- first created 02/07/2015
; -- modification from JMA_adv_abm_v0_1.nlogo file
; --  the modificaiton include 
; --  - three types agents
; --  - retunr of revenue from investment (not capital)
; --  - from version 0.2
; --  - Land searching, everywhere for large dev, in-radius for small dev
; --  - Land decision to build,or no build
; --  - Land expansion and land values change according to feasible pixel
; --  - Developer profit is collected during the run
; --  - Developer has typology . Small, large, and mix
; --  - 23/10/2015
; --  - Decision on developing = Revenue should be larger than init capital + loan for large dev
; --  - Regained capital = capital after cost for the development + expected revenue
; --  - 30/10/2015
; --  - Addition of variability in the developers capital and characteristics
; --  - 7/APr/2016  ; This is ABM version 1 (three types developers)
; --  - Addition of adm boundary

; some facts from winarso
; 1 ha = 50 houses p.166
; 57 % developer build in less than 100 ha. p.166
; 64% location permit only developed, never 100% p.166
; On average, 1338 house unit per year produced by the developer (1996) p172
; should be more if the 1:3:6 rule is implemented
; range of size, 100-250 ha, equals to 11-28 pixels

; buyers are in 25-30 yo p.190
; average hh size 4.3 p.190

; conversion of urban area into house, CO2, or population, has significant impact on urban policy.


;==========================
; 1. DEFINE THE VARIABLES
;==========================
extensions [gis]
globals    [view-mode landCov94 landValue newraster]
breed      [developers developer]

developers-own [
                developer-type                        ; classification of developers based on capital, "large", "medium", and "small"
                developer-age				                  ; Time frome first land acquisition to release
                developer-capital-init		            ; Unit in billion IDR. Initial capital
                developer-capital-loan 		            ; Unit in billion IDR. loan from external sources, max 75% from initial capital
                developer-capital			                ; Unit in billion IDR. Accumulated capital owned to purchase, develop land (Z)
                developer-revenue-here                ; Expected Current Revenue on location (R-star-x)             
                developer-cost-here                   ; Cost at current location 
                developer-profit-here                 ; The urban development profit on its current position (P-x)
                developer-profit-expected 	          ; The expected urban development profit based on target (P-star)
                developer-profit-cumul                ; Unit in billion IDR. Cummulative Income from selling the house
                
                developer-mode                        ; search, develop, expand
                developer-lv-perceived                ; land-value-perceived ()
                developer-land-size                   ; Current occupied land size (in ha)
                developer-land-size-cumul             ; Cumulative current occupied land size (in ha)
                
                developer-search-area                 ; check p76 thesis (in cells)                 
                developer-target-size                 ; tarket size have already in mind (Kaiser) in ha
                developer-develop-time                ; construction time until land is ready to release (in months)
                developer-count-down                  ; count down for the construction time
                developer-patches                     ; list of patches for urban development
                
               ]


patches-own [
             field-land-use-ori                       ; original values before simulation starts
             field-land-value-ori                     ; original values before simulation starts
             field-dist-cbd-ori                       ; original values before simulation starts
      
             field-land-use                           ; Current land use at start is 1994
             field-land-value                         ; Unit in juta (million IDR) per sq m ; raw land value
             field-land-value-pxl                     ; Unit in juta (million IDR) per pixel 
             field-land-value-perceived
             field-dist-cbd                           ; Unit in pixel (x 30 m) Distance in km from CBD (Jakarta)
             field-dist-road                          ; Unit in km. Distance in km from the main or toll roads
             field-dist-road-cost                     ; unit in billion IDR
             field-dist-new-urban                     ; distance to new urban for updating land values
             field-area                               ; Unit in pixel. Size of contigous area in one developed site
             field-visited?                           ; Y or N visited?
             field-assessed?                          ; Y or N, land has been assessed?
             field-developed?                         ; Y or N, land has been developed?
            ]



;==========================
; 2. LOAD 
;==========================

to load-input

  clear-all 
  
  gis:load-coordinate-system (word "Input/landcover_94.prj")
  gis:set-world-envelope [644205 756105 -753435 -652635]
  
  ; Load land use in 1994
  file-open "1994_jma_rsmpl.txt"
  foreach sort patches [ask ? [set field-land-use-ori file-read] ]
  file-close
  
  ; Load distance from toll road 
  file-open "jma_tollroad_buff.txt"
  foreach sort patches [ask ? [set field-dist-road file-read] ]
  file-close  
  
  ; Load land-values
  file-open "jma_land_val_v5.txt"
  foreach sort patches [ask ? [set field-land-value-ori file-read] ]
  file-close 
  
  let field-land-value-negative patches with [field-land-value-ori != -9999 and field-land-value-ori < 0]
  ask field-land-value-negative 
  [
    set field-land-value-ori 1
  ]  
  
  ask patches with [ field-land-value-ori != -9999 ]
  [
    set field-land-value-pxl 
    precision (field-land-value-ori * 90) 2           ; land value in pixel, unit billion (milyar)/9 ha
    set field-land-value ;-ori 
    precision (field-land-value-ori / 1000) 2         ; in billion (milyar) originally in million (juta) IDR 
  ]
  
  ; Load distance from CBD
  ask patches
  [
    set field-dist-cbd-ori distancexy 192 224                          ; distance from CBD (Monas)
    set field-dist-cbd-ori field-dist-cbd-ori * 0.3                    ; distance from CBD in km
    set field-dist-cbd-ori precision field-dist-cbd-ori 1              ; set two decimal behind comma
  ]
  
  
  ; load spatial attributes : legend, north, scale, adm
    
  ; load adm boundary
  let boundary gis:load-dataset (word "Input/JMA_adm2_jkt_merge.shp")
  foreach gis:feature-list-of boundary
   [
     gis:set-drawing-color 3
     gis:draw ? 1.0
   ]
   
   ; load circular lines
  let circular gis:load-dataset (word "Input/JMA_radius.shp")
  foreach gis:feature-list-of circular
   [
     gis:set-drawing-color white
     gis:draw ? 2.5
     
     gis:set-drawing-color red
     gis:draw ? 2
   ]
  
  
;  load legendScale
;  let legendScale gis:load-dataset (word "Input/legend_scale_10_20.shp")
;  foreach gis:feature-list-of legendScale
;   [
;     gis:set-drawing-color 0
;     gis:draw ? 2.0     
;   ]
;  
;    ; load legendNorth
;  let legendNorth gis:load-dataset (word "Input/legend_north.shp")
;  foreach gis:feature-list-of legendNorth
;   [
;     gis:set-drawing-color 0
;     gis:draw ? 1.0
;     gis:fill ? 0
;   ]
; 
  
end
	


;==========================
; 3. MODEL AT 'START'
;==========================

to setup 
  clear-turtles                                       ; clear all 
  clear-all-plots                                     ; clear all plots
  
  define-land                                         ; set default parameters for environment
  define-developers-small                             ; display small dev, and load initial values
  define-developers-med                               ; display medium dev, and load initial values
  define-developers-large                             ; display large dev, and load initial values
    
  view-landuse
  reset-ticks
end



;==========================
; 4. MODEL AT 'GO'
;==========================
; according to procedure define on the paper
; the developer perfomrs 
; (i) land find ; searching for the land
; (ii) land dev assessment ; calculate based on cost-profit analytical curve, whether development is profitbale
; (iii) land dev decision; if it is profitable; then take the land otherwise leave
; (iv) land action; if yes; convert the land into urban and update the land values
; stop after t+i ticks

to go
  
  random-seed new-seed         ; permutate the random seeds
  
  land-development-find        ; searching for land
  land-development-assessment  ; assessment based on " Profit = Revenue - Cost "
  land-development-decision    ; decision to develop, " yes or no ", based on the expected profit
  land-development-action      ; development action, no develop, land banking, based on the notion of??

  update-developer             ; update the developer's profit, mode, and capital, land size
  update-view                  ; update view
  update-plot                  ; update the plot

  if ticks = (12 * 6)          ; One tick equals to one month, 12 ticks = 1 year. timeframe 6 years, 1994 - 2000
  [stop]
  tick
  
end


;==========================
; VIEW THE INPUT
;==========================
; view active map as requested by the user

to view-landuse
  ask patches
  [
    if field-land-use = 0      [set pcolor grey + 2]              ; No data  
    if field-land-use = 1      [set pcolor grey + 2 ]             ; Sea water blue - 2
    if field-land-use = 2      [set pcolor blue + 2]              ; Water bodies  
    if field-land-use = 3      [set pcolor white]                 ; Vegetation dense green + 3
    if field-land-use = 4      [set pcolor white]                 ; Vegetation sparse green
    if field-land-use = 5      [set pcolor pink]                  ; Residential dense
    if field-land-use = 6      [set pcolor yellow]                ; Residential sparse/vegetated
    if field-land-use = 7      [set pcolor red]                   ; Commercial industries 
    if field-land-use = 50     [set pcolor black]                 ; NEW resid area developed by small dev 
    if field-land-use = 51     [set pcolor black]                 ; NEW resid area developed by medium dev 
    if field-land-use = 52     [set pcolor black]                 ; NEW resid area developed by large dev 
  ]
end

to view-distance-road
  ask patches
  [
    if field-dist-road > 0
    [
      set pcolor scale-color 75 (ln field-dist-road) 3  0         ; ori color 115
    ]
    
    if (field-dist-road = -9999)     [set pcolor black]           ; NoData
    if field-land-use = 0            [set pcolor grey + 2]        ; No data 
    if field-land-use = 1            [set pcolor grey + 2 ]       ; Sea water
    if field-land-use = 50           [set pcolor black]           ; NEW resid area developed by small dev (0)
    if field-land-use = 51           [set pcolor black]           ; NEW resid area developed by med dev (1)
    if field-land-use = 52           [set pcolor black]           ; NEW resid area developed by large dev (2)
  ]
end

to view-land-value
  ask patches
  [
    if field-land-value-pxl > 0
    [
      set pcolor scale-color 75 (ln field-land-value-pxl)  7 4.5
    ]
    
    if field-land-value-ori = -9999  [set pcolor grey + 2]        ; NoData
    if field-land-use = 1            [set pcolor grey + 2]        ; Sea water
    if field-land-use = 50           [set pcolor black]           ; NEW resid area developed by small dev (0)
    if field-land-use = 51           [set pcolor black]           ; NEW resid area developed by med dev (1)
    if field-land-use = 52           [set pcolor black]           ; NEW resid area developed by large dev (2)
  ]
end

to view-distance-cbd
  ask patches
  [
    set pcolor scale-color 75 (ln (field-dist-cbd + 0.1)) 4 0     ; ori color cyan
    
    if field-land-use = 1            [set pcolor grey + 2]        ; Sea water
    if field-land-use = 0            [set pcolor grey + 2]        ; No data 
    if field-land-use = 50           [set pcolor black]           ; NEW resid area developed by small dev (0)
    if field-land-use = 51           [set pcolor black]           ; NEW resid area developed by large dev (1)
    if field-land-use = 52           [set pcolor black]           ; NEW resid area developed by large dev (2)
  ]  
end



;==========================
; Define
;==========================

; Define the developers characteristics
; Fact: according to winarso p79, not more than 50 developers in JMA

; Define developer small. It has a capital of 1000.10^6 IDR (1000 miliar or 10000 billion IDR)
to define-developers-small
  
  create-developers num-dev-small 
  [ 
    let land-position patches with [field-land-use > 2]                                                 
    move-to one-of land-position
    
    set size                      10
    set shape                     "person"
    set label-color               lime
    set color                     lime
    
    set developer-type            "small"
    set developer-mode            "searching"
    set developer-age             0
    set developer-land-size       0
    set developer-profit-cumul    0
    set developer-develop-time    12
    
    let init-capital-small-min    1000
    let init-capital-small-max    5000
    let init-loan-small           20 / 100
    let teta-error                3  / 100
    let profit-margin             15  / 100
    
    set developer-capital-init    random (init-capital-small-max - init-capital-small-min) + init-capital-small-min 
    set developer-capital-loan    developer-capital-init        * init-loan-small
    set developer-capital         developer-capital-init        + developer-capital-loan

    set developer-profit-expected developer-capital             * profit-margin
    set developer-revenue-here    developer-capital             * [field-revenue-dist-cbd] of patch-here 
    set developer-lv-perceived    land-value-perceived
    set developer-count-down      developer-develop-time

    update-developer-characteristic
  ]
end


to define-developers-med
  
  create-developers num-dev-med
  [ 
    let land-position patches with [field-land-use > 2]                                                 
    move-to one-of land-position
    
    set size                      10
    set shape                     "person"
    set label-color               yellow
    set color                     yellow
    
    set developer-type            "medium"
    set developer-mode            "searching"
    set developer-age             0
    set developer-land-size       0
    set developer-profit-cumul    0
    set developer-develop-time    12
    
    let init-capital-med-min      5000
    let init-capital-med-max      7000
    let init-loan-med             50 / 100
    let teta-error                3  / 100
    let profit-margin             15  / 100
    
    set developer-capital-init    random (init-capital-med-max - init-capital-med-min) + init-capital-med-min  
    set developer-capital-loan    developer-capital-init        * init-loan-med
    set developer-capital         developer-capital-init        + developer-capital-loan

    set developer-profit-expected developer-capital             * profit-margin
    set developer-revenue-here    developer-capital             * [field-revenue-dist-cbd] of patch-here 
    set developer-lv-perceived    land-value-perceived
    set developer-count-down      developer-develop-time

    update-developer-characteristic
  ]
end


to define-developers-large
  
  create-developers num-dev-large 
  [
    let land-position patches with [field-land-use > 2]                                                 
    move-to one-of land-position   ; alt setxy random-xcor random-ycor ;192 224
    
    set size                      12
    set shape                     "person"
    set label-color               red
    set color                     red
    
    set developer-type            "large"
    set developer-mode            "searching"
    set developer-age             0
    set developer-land-size       0
    set developer-profit-cumul    0
    set developer-develop-time    18
        
    let init-capital-large-min    7000
    let init-capital-large-max    10000
    let init-loan-large           75 / 100
    let teta-error                3  / 100
    let profit-margin             15 / 100
    
    set developer-capital-init    random (init-capital-large-max - init-capital-large-min) + init-capital-large-min  
    set developer-capital-loan    developer-capital-init        * init-loan-large
    set developer-capital         developer-capital-init        + developer-capital-loan

    set developer-profit-expected developer-capital             * profit-margin
    set developer-revenue-here    developer-capital             * [field-revenue-dist-cbd] of patch-here 
    set developer-lv-perceived    land-value-perceived
    set developer-count-down      developer-develop-time

    update-developer-characteristic
  ]
end


to define-land
  ask patches
  [
    set field-visited?              "false"                                 ; deauflt pixels are not visited
    set field-assessed?             "false"                                 ; default pixels are not assessed
    set field-developed?            "false"                                 ; default pixels are not developed
    
    set field-land-use              field-land-use-ori
    set field-dist-cbd              precision (field-dist-cbd-ori)          2 
    set field-land-value-pxl        precision (field-land-value-ori * 90)   2           ; land value per pixel or per 9 ha, unit billion (milyar IDR)/ per pixel or per 9 ha
    set field-land-value            precision (field-land-value-ori / 1000) 2           ; land value in billion (milyar) originally in million (juta) IDR per m square    
    set field-land-value-perceived  precision (land-value-perceived)        2           ; perceived land values add random  
  ] 
end





;==========================
; MAIN PROCESS
;==========================


;========================== 1. Land searching

to land-development-find
; option, movement (i) random, (ii) frog jump, and (iii) fwd shift
; option (i)    setxy random-xcor random-ycor 
; option (ii)   move-to one-of find-best-patches
; option (iii)  downhill field-land-value-perceived 

  ask developers 
  [
    if (developer-type = "large") and (developer-mode = "searching")
    [
      ifelse (developer-capital > 0) and (any? patches with [field-visited? = "false"])          
      [
        set developer-cost-here    0
        set developer-land-size    0 
        set developer-profit-here  0
        
        let find-suit-patches   patches with 
                              [ field-land-value >= 0      and
                                field-visited?   = "false" and
                                field-land-use   > 2
                              ]  
                                               
        ifelse any? find-suit-patches 
        [ move-to one-of find-suit-patches ]
        [ die ] ; out from the arena
      
        let search-cost             0.100      ; Rp. 100 juta (million)
        set developer-capital       precision  (developer-capital - search-cost) 2
        set developer-lv-perceived  precision  (land-value-perceived )           2
      
        ask patch-here [ set field-visited? "true" ]
      ]
      [ if developer-capital <= 0 [die]
        if patches with [field-visited? = "false"] = nobody [stop]
        
      ] 
    ]
    
    
   if (developer-type = "medium") and (developer-mode = "searching")
    [
      ifelse (developer-capital > 0) and (any? patches with [field-visited? = "false"])          
      [
        set developer-cost-here    0
        set developer-land-size    0 
        set developer-profit-here  0
        
        let find-suit-patches   patches with 
                              [ field-land-value >= 0      and
                                field-visited?   = "false" and
                                field-land-use   > 2
                              ]  
                                               
        ifelse any? find-suit-patches 
        [ move-to one-of find-suit-patches ]
        [ die ] ; out from the arena
      
        let search-cost             0.050      ; Rp. 50 juta (million)
        set developer-capital       precision  (developer-capital - search-cost) 2
        set developer-lv-perceived  precision  (land-value-perceived )           2
      
        ask patch-here [ set field-visited? "true" ]
      ]
      [ if developer-capital <= 0 [die]
        if patches with [field-visited? = "false"] = nobody [stop]
        
      ] 
    ]
    
    
    if (developer-type = "small") and (developer-mode = "searching")
    [
      ifelse ( developer-capital > 0 and any? patches with [(field-visited? = "false")]  )
      [
        set developer-cost-here    0
        set developer-land-size    0 
        set developer-profit-here  0
        
        let find-suit-patches   patches in-radius ( developer-search-area ) with 
                                [ field-land-value >= 0       and
                                  field-visited?   = "false"  and
                                  field-land-use   > 2
                                ]  

        ifelse any? find-suit-patches 
        [ move-to one-of find-suit-patches ]
        [ die ] ; out from the arena
        
        let search-cost             0.010      ; Rp. 10 juta (million)
        set developer-capital       precision  (developer-capital - search-cost) 2
        set developer-lv-perceived  precision  (land-value-perceived )           2
        ask patch-here [ set field-visited? "true" ]
      ]
      [
        if developer-capital <= 0 [die]
        if patches with [field-visited? = "false"] = nobody [stop]
      ]
      
    ]
    
  ]
    
    
    
end


;========================== 2. Land assessment

; Land assessment analises the expected revenue, and cost estimated from the pixel where the developers currently stand.
; The construction composes of two parts; the cost of the development in the centre pixel
; and the neighbouring cells
; the cost in the centre consists of perceived land val, connecting road, and land converting cost
; the neighbouring cost, is without the connecting road
; the potential revenues based on the logistic based function field-revenue-dist-cbd of patches in the surrounding
; and multiply with the perceived land value.
; and multiply with the perceived field_land.
to land-development-assessment
  
  ask developers 
  [
    if  (developer-type = "large") and (developer-mode = "searching")
    [
      ; cost
      let search-radius-vicinity                       10                         ; cells or equals to 10 x 0.3 km = 3 km
      let patches-neighbour        patches in-radius 
          search-radius-vicinity   with  [ field-land-value-pxl > 0 ]                ; field-assessment-radius
      let patches-neighbour-target min-n-of   
          (developer-target-size / 9) patches-neighbour [distance myself]        ; change ha to cell; the closer and lower cost cell
            
      set developer-cost-here   ( [field-centre-cost] of patch-here  + sum [field-neighbour-cost] of patches-neighbour-target   )  
      set developer-cost-here    precision developer-cost-here 2
      set developer-land-size    count patches-neighbour-target
      
      set developer-patches      (patch-set patch-here patches-neighbour-target)
      
      ; expected revenue
      set developer-revenue-here sum ([field-revenue-dist-cbd * land-value-perceived] of developer-patches )
      set developer-revenue-here precision  developer-revenue-here 2
      
      
      ; profit
      set developer-profit-here (developer-revenue-here - developer-cost-here)
      set developer-profit-here precision developer-profit-here 2 
      ask patches-neighbour-target 
      [ set field-assessed? "true" 
        set field-visited?  "true"
      ]
    ]
    
    
   if  (developer-type = "medium") and (developer-mode = "searching")
    [
      ; cost
      let search-radius-vicinity                       5                         ; cells or equals to 10 x 0.3 km = 3 km
      let patches-neighbour        patches in-radius 
          search-radius-vicinity   with [ field-land-value-pxl > 0 ]                ; field-assessment-radius
      let patches-neighbour-target min-n-of   
          (developer-target-size / 9) patches-neighbour [distance myself]        ; change into selecting the closer and lower cost cell
            
      set developer-cost-here   ( [field-centre-cost] of patch-here  + sum [field-neighbour-cost] of patches-neighbour-target   )                                                  ; total cost
      set developer-cost-here    precision developer-cost-here 2
      set developer-land-size    count patches-neighbour-target

      set developer-patches      (patch-set patch-here patches-neighbour-target)
      
      ; expected revenue
      set developer-revenue-here sum ([field-revenue-dist-cbd * land-value-perceived] of developer-patches )
      set developer-revenue-here precision  developer-revenue-here 2
      
      ; profit
      set developer-profit-here (developer-revenue-here - developer-cost-here)
      set developer-profit-here precision developer-profit-here 2 
      ask patches-neighbour-target 
      [ set field-assessed? "true" 
        set field-visited?  "true"
      ]
    ]
    
    
    
    if  (developer-type = "small") and (developer-mode = "searching")
    [
      ; cost
      let search-radius-vicinity                       5                         ; cells or equals to 10 x 0.3 km = 3 km
      let patches-neighbour        patches in-radius 
          search-radius-vicinity   with [ field-land-value-pxl > 0 ]                ; field-assessment-radius
      let patches-neighbour-target min-n-of   
          (developer-target-size / 9) patches-neighbour [distance myself]        ; change into selecting the closer and lower cost cell
            
      set developer-cost-here   ( [field-centre-cost] of patch-here  + sum [field-neighbour-cost] of patches-neighbour-target   )                                                  ; total cost
      set developer-cost-here    precision developer-cost-here 2
      set developer-land-size    count patches-neighbour-target

      set developer-patches      (patch-set patch-here patches-neighbour-target)
      
      ; expected revenue
      set developer-revenue-here sum ([field-revenue-dist-cbd * land-value-perceived] of developer-patches )

      ;set developer-revenue-here (   ( [field-revenue-dist-cbd * field-centre-cost] of patch-here)  +
      ;                          sum  ( [field-revenue-dist-cbd * field-neighbour-cost] of patches-neighbour-target )  )
      set developer-revenue-here precision  developer-revenue-here 2
      
      ; profit
      set developer-profit-here (developer-revenue-here - developer-cost-here)
      set developer-profit-here precision developer-profit-here 2 
      ask patches-neighbour-target 
      [ set field-assessed? "true" 
        set field-visited?  "true"
      ]
    ]
    
    
  ]
 
 end


;========================== 3. Land decision
to land-development-decision
  ask developers 
  [ 
    if developer-mode = "searching"
    [
      ifelse  (developer-revenue-here >= developer-capital) and
              (developer-cost-here    <= developer-capital) and
              (developer-profit-here  >= developer-profit-expected) ; maybe use a range
              
      [ set developer-mode "developing" ]
      [ set developer-mode "searching"  ] 
  
    ]  ] 
end



;========================== 4. Land action
; set new land cover
; set new land value
; set new developer profit
; set new developer capital
to land-development-action

  ask developers 
  
  [ 
    ; action by small developer
    if (developer-type = "small")      and 
       (developer-mode = "developing") and
       (developer-count-down > 0)
       
       [
         set label developer-count-down
         set developer-count-down (developer-count-down - 1)   ;decrement-timer
         set developer-capital    (developer-capital - (developer-cost-here / developer-develop-time))  ; pay to acquire and develop the land
       
       ]
    
    if (developer-type = "small")      and 
       (developer-mode = "developing") and
       (developer-count-down = 0)

       [
         ask developer-patches
         [
           set field-assessed?    "true" 
           set field-visited?     "true"
           set field-developed?   "true"   
           set field-land-use      50
           set pcolor              black
         ]
         
         update-land-value
         update-developer-capital
         
         set developer-mode  "searching"
         set developer-count-down developer-develop-time

       ]
       
     
     ; action by medium developer
     
    if (developer-type = "medium")     and 
       (developer-mode = "developing") and
       (developer-count-down > 0)
       
       [
         set label developer-count-down
         set developer-count-down (developer-count-down - 1)   ; decrement-timer
         set developer-capital    (developer-capital - (developer-cost-here / developer-develop-time))  ; pay to acquire and develop the land
       ]
    
    if (developer-type = "medium")     and 
       (developer-mode = "developing") and
       (developer-count-down = 0)

       [
         ask developer-patches
         [
           set field-assessed?    "true" 
           set field-visited?     "true"
           set field-developed?   "true"   
           set field-land-use      51
           set pcolor              black
         ]
         
         update-land-value
         update-developer-capital
         
         set developer-mode  "searching"
         set developer-count-down developer-develop-time
       ]
       
       
       
     ; action by large developer
     
    if (developer-type = "large")      and 
       (developer-mode = "developing") and
       (developer-count-down > 0)
       
       [
         set label developer-count-down
         set developer-count-down (developer-count-down - 1)   ; decrement-timer
         set developer-capital    (developer-capital - (developer-cost-here / developer-develop-time))  ; pay to acquire and develop the land
       ]
    
    if (developer-type = "large")      and 
       (developer-mode = "developing") and
       (developer-count-down = 0)

       [
         ask developer-patches
         [
           set field-assessed?    "true" 
           set field-visited?     "true"
           set field-developed?   "true"   
           set field-land-use      52
           set pcolor              black
         ]
         
         update-land-value
         update-developer-capital
         
         set developer-mode  "searching"
         set developer-count-down developer-develop-time
       ]
       
       
  ]
  
end




;==========================
; UPDATE
;==========================


to update-developer
  if any? developers
  [ ask developers   
    [                                                               ; categorize the developer as per capital (and the size owned??)
      if (developer-mode = "searching") 
      [
        let developer-capital-low  5000      
        let developer-capital-high 7000                    
        if  developer-capital <= developer-capital-low  [set developer-type "small"]
        if  developer-capital >  developer-capital-low  and 
            developer-capital <= developer-capital-high [set developer-type "medium"]  
        if  developer-capital >  developer-capital-high [set developer-type "large"]
      ]
    
      set developer-age (developer-age + 1)                         ; developer gets older regardles the capital or mode
    
      update-developer-characteristic                               ; update the characteristics
    ]
  ] 
  
end


  
to update-developer-characteristic
  ask developers
  [
        
    set developer-capital-init     precision developer-capital-init    2
    set developer-capital-loan     precision developer-capital-loan    2
    set developer-capital          precision developer-capital         2
    set developer-profit-expected  precision developer-profit-expected 2
    set developer-profit-cumul     precision developer-profit-cumul    2
    set developer-revenue-here     precision developer-revenue-here    2
    set developer-lv-perceived     precision land-value-perceived      2  
    set label                      precision developer-capital         2 
    
    if developer-type = "small" 
      [ 
        ifelse (developer-mode = "developing") 
        [ set color gray
          set label developer-count-down
        ]
        [ 
          set size                        10
          set label-color                 lime
          set color                       lime
          
          set   developer-search-area     30                     
          set   developer-target-size     10                  ; 10 hectare =~ 1 cells
          set   developer-develop-time    12
        ]

      ]
      
      if developer-type = "medium" 
      [ 
        ifelse (developer-mode = "developing") 
        [ set color gray
          set label developer-count-down
        ]
        [ 
          set size                        10
          set label-color                 yellow
          set color                       yellow
          
          set   developer-search-area     100                     
          set   developer-target-size     50                  ; 10 hectare =~ 1 cells
          set   developer-develop-time    15
        ]

      ]
      
     if developer-type = "large" 
      [ 
        ifelse (developer-mode = "developing") 
        [ 
          set color gray
          set label developer-count-down
        ]
        [ 
          set size                        12
          set label-color                 red
          set color                       red
          
          set   developer-search-area     500                     
          set   developer-target-size     100                   ; 100 hectare =~ 10 cells
          set   developer-develop-time    18                    ; 18 ticks (months) they have no limit on deadline
        ]
        
      ]
  ]
  end
  


to update-developer-capital      ; developer procedure

  set developer-land-size-cumul                             ; accumulate the land size 
     (developer-land-size-cumul + developer-land-size)
  set developer-profit-cumul                                ; accumulate the profit
     (developer-profit-cumul    + developer-profit-here)
  set developer-capital                                     ; added the profit to capital after xx tick
     (developer-capital         + developer-revenue-here)

end


to update-land-value             ; patch procedure after the "land stay" loop
  ask patches in-radius 12 
  [
    set field-dist-new-urban   distance myself 
    set field-land-value-pxl   (land-value-increased * field-land-value-pxl)
    set field-land-value-pxl   precision field-land-value-pxl 2
  ]

end

 

to update-view
  if view-mode = "land-cover" [view-landuse]
  if view-mode = "land-value" [view-land-value]
  if view-mode = "dist-cbd"   [view-distance-cbd]
  if view-mode = "dist-road"  [view-distance-road]
end



to update-stop
if not any? developers 
     or ( count developers <  1 )
     or not any? patches with [(field-visited? = "false")] 
  [stop]
end


to update-plot
  set-current-plot "New urban"
  set-current-plot-pen "New urban by small dev"
  plot (count patches with [field-land-use = 50] * 9)
  set-current-plot-pen "New urban by med dev"
  plot (count patches with [field-land-use = 51] * 9)
  set-current-plot-pen "New urban by large dev"
  plot (count patches with [field-land-use = 52] * 9)
  
 
end

;==========================
; To REPORT
;==========================

; perceived land values according to the developers
to-report land-value-perceived
  let random-error  10
  report (field-land-value-pxl +  random-float (random-error * field-land-value-pxl / 100)) ; price is always inflated than original
end


; report the Potential revenues with 
; unit in percent of developers capital?? or raw land value pixel
; Gaussian function
; based on empirical studies on different location or theory
to-report field-revenue-dist-cbd
  let alpha     1
  let beta      -3
  let dist-max  50
  report (( alpha * ( exp ( beta * (field-dist-cbd ^ 2) / (dist-max ^ 2)) )) + 1)                                
end


to-report field-road-construction
  ; report the cost of road construction with 
  ; unit in billion? juta IDR
  ; Gaussian function
  ; based on empirical studies on different location or theory
  let alpha     100
  let beta      -2
  let dist-max  15
  report 100 - ( alpha * ( exp ( beta * (field-dist-road ^ 2) / (dist-max ^ 2)) ))            ; 15 km from toll road, equal cost of 100 mill per km   
end


to-report field-site-clearance
  if field-land-use = 0      [ report field-land-value-pxl * 0   ]                  ; No data 
  if field-land-use = 1      [ report field-land-value-pxl * 0   ]                  ; Sea water
  if field-land-use = 2      [ report field-land-value-pxl * 0.5 ]                  ; Water bodies  
  if field-land-use = 3      [ report field-land-value-pxl * 0   ]                  ; Vegetation dense
  if field-land-use = 4      [ report field-land-value-pxl * 0   ]                  ; Vegetation sparse
  if field-land-use = 5      [ report field-land-value-pxl * 2   ]                  ; Residential dense
  if field-land-use = 6      [ report field-land-value-pxl * 0.2 ]                  ; Residential sparse/vegetated
  if field-land-use = 7      [ report field-land-value-pxl * 3   ]                  ; Commercial industries 
  if field-land-use = 50     [ report field-land-value-pxl * 1   ]                  ; NEW resid area by small dev 
  if field-land-use = 51     [ report field-land-value-pxl * 1   ]                  ; NEW resid area by large med
  if field-land-use = 52     [ report field-land-value-pxl * 1   ]                  ; NEW resid area by large dev      
end


to-report field-centre-cost
  report ( land-value-perceived + field-road-construction + field-site-clearance ) ; overhead component? large in large dev??
end


to-report field-neighbour-cost
  report ( land-value-perceived + field-site-clearance )
end


to-report land-value-increased
  let alpha     1
  let beta      -10
  let dist-max  20
  report ( 1 + (alpha * ( exp ( beta * (field-dist-new-urban ^ 2) / (dist-max ^ 2)) )) )                               
end


;==========================
; EXPORT
;==========================
; REMEMBER TO CHANGE the name of the folder OUTPUT/"DATE"/

to export-land-cover
  set newraster gis:patch-dataset field-land-use 
  let labelDev (word num-dev-small "_" num-dev-med "_" num-dev-large)
  gis:store-dataset newraster (word "Output/20160429/land_cover_" labelDev "_" precision timer 0 ".asc")  
end 

to export-land-value
  set newraster gis:patch-dataset field-land-value-pxl
  let labelDev (word num-dev-small "_" num-dev-med "_" num-dev-large)
  gis:store-dataset newraster (word "Output/20160429/land_value_" labelDev "_" precision timer 0 ".asc")
end 


to export-current-view
  let labelDev (word num-dev-small "_" num-dev-med "_" num-dev-large)
  set view-mode "land-cover"
  update-view
  export-view  (word "Output/20160429/Figure/" view-mode "_" labelDev "_" precision timer 0 ".png")
  set view-mode  "land-value"
  update-view
  export-view  (word "Output/20160429/Figure/" view-mode "_" labelDev "_" precision timer 0 ".png")
end


;==========================
; END
;==========================




;
@#$#@#$#@
GRAPHICS-WINDOW
210
10
779
545
-1
-1
1.5
1
8
1
1
1
0
0
0
1
0
372
0
335
0
0
1
ticks
30.0

BUTTON
93
28
196
61
Setup/Clear
setup
NIL
1
T
OBSERVER
NIL
S
NIL
NIL
1

BUTTON
92
64
197
97
GO
go\n
T
1
T
OBSERVER
NIL
Z
NIL
NIL
1

BUTTON
12
169
205
202
Land values (Rp. billion/sq m)
set view-mode \"land-value\"\nupdate-view\n\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
17
114
91
133
View layer
10
0.0
1

BUTTON
13
205
198
238
Distance to CBD (km)
set view-mode \"dist-cbd\"\nupdate-view
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
14
241
197
274
Distance to road (km)
set view-mode \"dist-road\"\nupdate-view
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
12
134
200
167
Land cover (1994)
set view-mode \"land-cover\"\nupdate-view
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
17
10
86
28
Setup
11
0.0
1

BUTTON
16
64
90
97
GO once
go
NIL
1
T
OBSERVER
NIL
A
NIL
NIL
1

TEXTBOX
17
289
167
307
Developers' parameters
11
0.0
1

BUTTON
17
29
91
62
Load map
load-input
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
719
565
786
610
Total (ha)
(count patches with [field-land-use >= 50] * 9)
17
1
11

MONITOR
786
10
915
55
Vegetation area (ha)
(count patches with [field-land-use = 3] * 9) + (count patches with [field-land-use = 4] * 9)
17
1
11

MONITOR
786
58
914
103
Existing urban (ha)
(count patches with [field-land-use = 5] * 9) + (count patches with [field-land-use = 6] * 9) + (count patches with [field-land-use = 55] * 9)
17
1
11

MONITOR
786
154
915
199
Field assessed (ha)
(count patches with [field-assessed? = \"true\"] * 9)
17
1
11

MONITOR
786
106
913
151
Field visited (cells)
count patches with [field-visited? = \"true\"]
17
1
11

SLIDER
15
308
187
341
num-dev-large
num-dev-large
0
50
16
1
1
NIL
HORIZONTAL

SLIDER
15
384
187
417
num-dev-small
num-dev-small
0
50
16
1
1
NIL
HORIZONTAL

MONITOR
851
352
913
397
Dev med
count developers with [developer-type = \"medium\"]
17
1
11

PLOT
789
413
989
563
New urban
months
New urb (ha)
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"New urban by small dev" 1.0 0 -13840069 true "" ""
"New urban by med dev" 1.0 0 -1184463 true "" ""
"New urban by large dev" 1.0 0 -2674135 true "" ""

MONITOR
786
352
846
397
Dev large
count developers with [developer-type = \"large\"]
17
1
11

BUTTON
16
445
141
478
test
land-development-find\nland-development-assessment\nland-development-decision\nland-development-action\nupdate-developer\nupdate-view\nupdate-plot\ntick\n
T
1
T
OBSERVER
NIL
Q
NIL
NIL
1

MONITOR
913
352
981
397
Dev small
count developers with [developer-type = \"small\"]
17
1
11

PLOT
786
200
986
350
#Developer
months
#Developer
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -2674135 true "" "plot count developers with [developer-type = \"large\"]"
"pen-1" 1.0 0 -13840069 true "" "plot count developers with [developer-type = \"small\"]"
"pen-2" 1.0 0 -1184463 true "" "plot count developers with [developer-type = \"medium\"]"

MONITOR
923
564
987
609
Urb Small
(count patches with [field-land-use = 50] * 9)
17
1
11

MONITOR
790
565
857
610
Urb Large
(count patches with [field-land-use = 52] * 9)
17
1
11

TEXTBOX
19
504
169
522
Large developer
11
15.0
1

TEXTBOX
18
533
168
551
Small-capital developer
11
65.0
1

TEXTBOX
18
547
168
565
Developing developer
11
5.0
1

TEXTBOX
18
486
168
504
LEGEND :
11
0.0
1

BUTTON
211
548
343
581
NIL
export-land-cover
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
480
549
583
582
export view
export-current-view
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
347
549
478
582
NIL
export-land-value
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
15
345
187
378
num-dev-med
num-dev-med
0
50
13
1
1
NIL
HORIZONTAL

TEXTBOX
18
519
168
537
Medium-capital developer
11
44.0
1

MONITOR
860
564
919
609
Urb Med
(count patches with [field-land-use = 51] * 9)
17
1
11

@#$#@#$#@
## WHAT IS IT?

The model represents the spatial behaviour of the private residential developers in searching and converting the non-urban land for new residential area. The model sets the aim to simulate the spatial consequence of developers on the urban pattern and land values in Jakarta Metropolitan Area, Indonesia.

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.0.5
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="JMA_Adv_scenario" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>; count patches with [field-land-use &gt; 49] ; no separation</metric>
    <metric>; count patches with [field-land-use = 50] ; new urban by small dev</metric>
    <metric>; count patches with [field-land-use = 51] ; new urban by med   dev</metric>
    <metric>; count patches with [field-land-use = 52] ; new urban by large dev</metric>
    <metric>; modes [developer-capital] of developers with [developer-type = "small"]</metric>
    <enumeratedValueSet variable="num-dev-large">
      <value value="0"/>
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-dev-med">
      <value value="0"/>
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-dev-small">
      <value value="0"/>
      <value value="50"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="JMA_Adv_scenario_mix" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-land-cover
export-land-value</final>
    <enumeratedValueSet variable="num-dev-large">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-dev-med">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-dev-small">
      <value value="50"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
