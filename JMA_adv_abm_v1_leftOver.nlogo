; behaviour space alternative
; count patches with [field-land-use > 49] ; no separation
; count patches with [field-land-use = 50] ; new urban by small dev
; count patches with [field-land-use = 51] ; new urban by med   dev
; count patches with [field-land-use = 52] ; new urban by large dev
; modes [developer-capital] of developers with [developer-type = "small"]


;========================== 2. Land assessment
    if  (developer-type = "small") and (developer-mode = "searching")
    [
      ; cost
      let search-radius-vicinity                       5                         ; cells or equals to 10 x 0.3 km = 3 km
      let patches-neighbour        patches in-radius 
          search-radius-vicinity   with [ field-land-value-pxl > 0 ]                ; field-assessment-radius
      let patches-neighbour-target min-n-of   
          (developer-target-size / 9) patches-neighbour [distance myself]        ; change into selecting the closer and lower cost cell
            
      set developer-cost-here   ( [field-total-cost] of patch-here  + sum [field-expansion-cost] of patches-neighbour-target   )                                                  ; total cost
      set developer-cost-here    precision developer-cost-here 2
      set developer-land-size    count patches-neighbour-target

      set developer-patches      (patch-set patch-here patches-neighbour-target)
      
      ; expected revenue
      set developer-revenue-here [field-profit-as-dist-cbd * land-value-perceived] of developer-patches 
      set developer-revenue-here (   ( [field-profit-as-dist-cbd * land-value-perceived] of patch-here)  +
                                sum  ( [field-profit-as-dist-cbd * land-value-perceived] of patches-neighbour-target )  )
      set developer-revenue-here precision  developer-revenue-here 2
      
      ; profit
      set developer-profit-here (developer-revenue-here - developer-cost-here)
      set developer-profit-here precision developer-profit-here 2 
      ask patches-neighbour-target 
      [ set field-assessed? "true" 
        set field-visited?  "true"
      ]
    ]

;========================== 3. Land decision
to land-development-decision
  ask developers 
  [ 
    if (developer-type = "large")  and (developer-mode = "searching")
    [
      ifelse  (developer-revenue-here >= developer-capital) and
              (developer-cost-here    <= developer-capital) and
              (developer-profit-here  >= developer-profit-expected) ; maybe use a range
              
      [ set developer-mode "developing" ]
      [ set developer-mode "searching"  ] 
    ]
    
    if (developer-type = "medium")  and (developer-mode = "searching")
    [
      ifelse  (developer-revenue-here >= developer-capital) and
              (developer-cost-here    <  developer-capital) and
              (developer-profit-here  >  developer-profit-expected) ; maybe use a range
              
      [ set  developer-mode "developing" ]
      [ set developer-mode "searching"  ]
    ]
    
    if (developer-type = "small")  and (developer-mode = "searching")
    [
      ifelse  (developer-revenue-here >= developer-capital) and
              (developer-cost-here    <  developer-capital) and
              (developer-profit-here  >  developer-profit-expected) ; maybe use a range
              
      [ set developer-mode "developing" ]
      [ set developer-mode "searching"  ]
    ]
    
  ] 
end