; Jabodetabek (JMA) urban model 
; cell size 300m x 300 m = 90000m2 = 9ha
; -- created by Agung Wahyudi
; -- first created 28/08/2014
; -- modified 29/08/2014 the go procedure
; -- modified 18/11/2014 add update procedure etc

; some facts from winarso
; 1 ha = 50 houses p.166
; 57 % developer build in less than 100 ha. p.166
; 64% location permit only developed, never 100% p.166
; On average, 1338 house unit per year produced by the developer (1996) p172
; should be more if the 1:3:6 rule is implemented
; range of size, 100-250 ha, equals to 11-28 pixels

; buyers are in 25-30 yo p.190
; average hh size 4.3 p.190


;==========================
; DEFINE THE VARIABLES
;==========================

breed [developers developer]

developers-own [
                developer-age                         ; Time frome first land acquisition to release
                developer-init-capital                ; Unit in billion IDR. Initial capital
                developer-loan                        ; Unit in billion IDR. loan from external sources, max 75% from initial capital
                developer-capital                     ; Unit in billion IDR. Accumulated capital owned to purchase, develop land
                developer-expected-profit             ; not sure, if this supposed to be here???
                developer-profits                     ; Unit in billion IDR. Income from selling the house
                developer-profits-prior
                developer-land-size
                
                developer-temp-cost                   ; temporary cost
                developer-cost-here
                developer-cost-neighbour
   
                
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
             field-area                               ; Unit in pixel. Size of contigous area in one developed site
             field-visited?                           ; Y or N visited?
             field-assessed?                          ; Y or N, land has been assessed?
             field-developed?                         ; Y or N, land has been developed?
            ]



;==========================
; LOAD 
;==========================

to load-input
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
    precision (field-land-value-ori * 90) 2                          ; land value in pixel, unit billion (milyar)/9 ha
    set field-land-value-ori 
    precision (field-land-value-ori / 1000) 5                        ; in billion (milyar) originally in million (juta) IDR 
  ]
  
  ; Load distance from CBD
  ask patches
  [
    set field-dist-cbd-ori distancexy 192 224                          ; distance from CBD (Monas)
    set field-dist-cbd-ori field-dist-cbd-ori * 0.3                    ; distance from CBD in km
    set field-dist-cbd-ori precision field-dist-cbd-ori 2              ; set two decimal behind comma
  ]
  
end



;==========================
; MODEL AT 'START'
;==========================

to setup
  clear-turtles                                       ; clear all 
  clear-all-plots                                     ; clear all plots
  
  reset
  define-patches                                      ; set default parameters for environment
  define-developers                                   ; display agent, and load initial values
    
  view-landuse
  reset-ticks
end

to reset
  ask patches
  [
    set field-land-use        field-land-use-ori
    set field-dist-cbd        field-dist-cbd-ori
    set field-land-value-pxl  precision (field-land-value-ori * 90000) 2 
        
  ]
end

;==========================
; MODEL AT 'GO'
;==========================

to go
  
  find-land
  assess-land
  development-decision
  expand-decision

  
  ; Updates
  update-agent
  update-field
  
  if not any? developers
  [stop]
  
end


;==========================
; VIEW THE INPUT
;==========================

to view-landuse
  ask patches
  [
    if field-land-use = 0      [set pcolor grey]                  ; No data  
    if field-land-use = 1      [set pcolor blue - 2]              ; Sea water
    if field-land-use = 2      [set pcolor blue + 2]              ; Water bodies  
    if field-land-use = 3      [set pcolor green + 3]             ; Vegetation dense
    if field-land-use = 4      [set pcolor green]                 ; Vegetation sparse
    if field-land-use = 5      [set pcolor pink]                  ; Residential dense
    if field-land-use = 6      [set pcolor yellow]                ; Residential sparse/vegetated
    if field-land-use = 7      [set pcolor red]                   ; Commercial industries 
    if field-land-use = 55     [set pcolor black]                 ; NEW resid area   
  ]
end

to view-distance-road
  ask patches
  [
    set pcolor scale-color 115 field-dist-road 0 20
    ; mask
    if (field-dist-road = -9999)     [set pcolor white]           ; NoData
    if field-land-use = 0            [set pcolor grey]            ; No data 
    if field-land-use = 1            [set pcolor blue - 2]        ; Sea water
  ]
end

to view-land-value
  ask patches
  [
    set pcolor scale-color 75 field-land-value-pxl 0 3000
    
    if field-land-value = -9999      [set pcolor grey]            ; NoData
    if field-land-use = 1            [set pcolor blue - 2]        ; Sea water
  ]
end

to view-distance-cbd
  ask patches
  [
    set pcolor scale-color cyan field-dist-cbd 0 200
    
    if field-land-use = 1            [set pcolor blue - 2]        ; Sea water
    if field-land-use = 0            [set pcolor grey]            ; No data 
  ]  
end



;==========================
; Define
;==========================

to define-developers
  ; according to winarso p79, not more than 50 developers in JMA
  create-developers num-developers
  [
    set color red - random-float 3                                                  
    setxy 192 224 
    set size 15
    set shape "person"
    set label-color white
    
    set developer-age 7
    set developer-land-size 0
    set developer-init-capital 
    random-normal initial-capital (3 * initial-capital / 100)
    set developer-loan (developer-init-capital * initial-loan / 100)
    set developer-capital (developer-init-capital + developer-loan)  
    
    set developer-init-capital precision developer-init-capital 2
    set developer-loan         precision developer-loan 2
    set developer-capital      precision developer-capital 2

    update-agent
  ]
end


to define-patches
  ask patches
  [
    set field-visited?    "false"                                 ; deauflt pixels are not visited
    set field-assessed?   "false"                                 ; default pixels are not assessed
    set field-developed?  "false"                                 ; default pixels are not assessed
    set field-land-value-perceived perceived-land-value           ; perceived land values add random  
  ] 
end



;==========================
; SUB-PROCESS
;==========================


to find-land
  ask developers
  [ 
    set developer-temp-cost 0
    set developer-land-size 0
    let find-suit-patches   patches with 
                            [ field-land-value > 0 
                              and (field-visited? = "false") 
                              and field-land-use > 2
                            ]
    let find-best-patches   min-n-of num-developers find-suit-patches [field-land-value-perceived]

    
    ifelse ( developer-capital > 0 and find-best-patches != nobody )
    [      
      move-to one-of find-best-patches
      set developer-capital (developer-capital - 0.010)
      
      ask patch-here [ set field-visited? "true" ]
      ask patches in-radius ( field-assessment-radius / .3) [ set field-visited? "true" ]
    ]
    [ die ]
  ]
  
end



to assess-land
  
  ask developers
  [
    ask patch-here 
    [ set field-assessed? "true" 
      set field-visited?  "true"
    ]
    
    let best-patches ( [field-total-cost] of patch-here )
    set developer-temp-cost best-patches 
    
    
    let neighbour-patches patches in-radius ( field-assessment-radius / .3) with [ field-land-value-pxl > 0 ]
    let sum-neighbour-land-value            ( sum [perceived-land-value]   of neighbour-patches )
    let sum-neighbour-site-devt             ( sum [field-site-improvement] of neighbour-patches )
    set developer-temp-cost                 ( developer-temp-cost + sum-neighbour-land-value )
    set developer-temp-cost                 ( developer-temp-cost + sum-neighbour-site-devt )
    set developer-temp-cost                 precision developer-temp-cost 2
  ]
end


to development-decision
  
  ask developers
  [ ifelse developer-temp-cost > ( developer-capital * 5 ) ; scenario optimist, higher 10, 5, 2.5, 1.25
    [ find-land ]
    [ develop-land ]
  ]
  
  
end



to develop-land
  ask patch-here
  [
    set field-assessed?    "true" 
    set field-visited?     "true"
    set field-developed?   "true"   
    set field-land-use      55
    set pcolor              black
    
  ]
  
  set developer-capital developer-capital - field-land-value-pxl ; field-total-cost
  set developer-land-size developer-land-size + 9
  
  while [ developer-capital > 0 ]
  [ expand-move
    expand-land
  ]
  
end

to expand-decision
  ask developers
  [ 
    while [ developer-capital > 0 ] [ expand-land ]
  ]
end
  

; let candidate-neighbour-patches min-n-of 20 neighbour-patches with [field-land-value > 0] [distance myself] 
; recharge capital otherwise no development

to expand-land
  ; expand-move
  
  ask patch-here 
  [ 
    set field-assessed? "true" 
    set field-visited?  "true"
    set field-developed?  "true"
    set field-land-use 55
    set pcolor black
  ]
  
  set developer-capital developer-capital - field-land-value-pxl ; field-expansion-cost
  set developer-land-size developer-land-size + 9

end

to expand-move
  
  let find-expand-patches min-one-of neighbors with [ field-developed? = "false" and field-land-value != -9999 ] [ field-land-value-perceived ]
  
  ifelse ( developer-capital > 0 and find-expand-patches != nobody )
  [ move-to find-expand-patches ]
  [ die ]  
  
end


; size? enough

to raise-price
  let field-new-urban patch-here 
  ask field-new-urban              [ set field-land-value-pxl ( field-land-value-pxl * 1.30 ) ]
  ask field-new-urban in-radius 3  [ set field-land-value-pxl ( field-land-value-pxl * 1.20 ) ]
  ask field-new-urban in-radius 6  [ set field-land-value-pxl ( field-land-value-pxl * 1.10 ) ]
  ask field-new-urban in-radius 9  [ set field-land-value-pxl ( field-land-value-pxl * 1.05 ) ]
  ask field-new-urban in-radius 12 [ set field-land-value-pxl ( field-land-value-pxl * 1.01 ) ]
  if field-land-value-pxl > 3000   [ set field-land-value-pxl 3000 ] 
end



;==========================
; To REPORT
;==========================

to-report perceived-land-value
  report (field-land-value-pxl +  random-float (3 * field-land-value-pxl / 100))
end

to-report field-road-construction
  
  ifelse (field-dist-road > 18)
  [ report random-normal (field-dist-road * 30) (( 30 * field-dist-road ) * 5 / 100) ] 
  
  [ ifelse (field-dist-road > 12)
    [ report random-normal (field-dist-road * 20) (( 20 * field-dist-road ) * 5 / 100)]
    
    [ ifelse (field-dist-road > 6 )
      [ report random-normal (field-dist-road * 18) (( 18 * field-dist-road ) * 5 / 100)] 
      
      [ ifelse (field-dist-road > 0 )
        [ report random-normal (field-dist-road * 15) (( 15 * field-dist-road ) * 5 / 100)]
        [ report field-dist-road * -1 ]   
    ]
  ]
  ]


end

to-report field-site-improvement
  if field-land-use = 0      [ report field-land-value-pxl * 0   ]                  ; No data 
  if field-land-use = 1      [ report field-land-value-pxl * 0   ]                  ; Sea water
  if field-land-use = 2      [ report field-land-value-pxl * 0   ]                  ; Water bodies  
  if field-land-use = 3      [ report field-land-value-pxl * 0   ]                  ; Vegetation dense
  if field-land-use = 4      [ report field-land-value-pxl * 0   ]                  ; Vegetation sparse
  if field-land-use = 5      [ report field-land-value-pxl * 0.5 ]                  ; Residential dense
  if field-land-use = 6      [ report field-land-value-pxl * 0.2 ]                  ; Residential sparse/vegetated
  if field-land-use = 7      [ report field-land-value-pxl * 5   ]                  ; Commercial industries 
  if field-land-use = 55     [ report field-land-value-pxl * 0.5 ]                  ; NEW resid area    
end

to-report field-total-cost
  report ( perceived-land-value + field-road-construction + field-site-improvement )
end

to-report field-expansion-cost
  report ( perceived-land-value + field-site-improvement )
end

to-report field-want-to-buy?
  report  field-total-cost <= developer-capital
end


;==========================
; UPDATE
;==========================

to update-agent
  if any? developers
  [ ask developers
    [ set label precision developer-capital 2 ]
  ]
end

to update-field
  view-landuse
  ; view-land-value
end



;==========================
; END
;==========================
@#$#@#$#@
GRAPHICS-WINDOW
210
10
966
713
-1
-1
2.0
1
10
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
29
198
62
Setup/Clear
setup
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
92
64
197
97
GO
find-land\nassess-land\ndevelopment-decision\n\n\n;go
T
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
169
157
202
Land values (blln IDR/sq m)
view-land-value
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
157
238
Distance to CBD (km)
view-distance-cbd
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
158
274
Distance to road (km)
view-distance-road
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
156
167
Land use (1994)
view-landuse
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
NIL
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

SLIDER
7
340
193
373
field-assessment-radius
field-assessment-radius
1
5
5
0.5
1
km
HORIZONTAL

SLIDER
8
304
193
337
num-developers
num-developers
1
10
10
1
1
developers
HORIZONTAL

SLIDER
6
376
192
409
initial-capital
initial-capital
1000
2000
2000
100
1
billion IDR
HORIZONTAL

SLIDER
7
411
192
444
initial-loan
initial-loan
0
75
75
1
1
% * init-capital
HORIZONTAL

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
972
153
1100
198
New urban area (ha)
(count patches with [field-land-use = 55] * 9)
17
1
11

MONITOR
972
11
1101
56
Vegetation area (ha)
(count patches with [field-land-use = 3] * 9) + (count patches with [field-land-use = 4] * 9)
17
1
11

MONITOR
972
59
1103
104
Existing urban (ha)
(count patches with [field-land-use = 5] * 9) + (count patches with [field-land-use = 6] * 9) + (count patches with [field-land-use = 55] * 9)
17
1
11

MONITOR
972
106
1101
151
Field assessed (ha)
(count patches with [field-assessed? = \"true\"] * 9)
17
1
11

MONITOR
972
201
1099
246
Field visited (fields)
count patches with [field-visited? = \"true\"]
17
1
11

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

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
