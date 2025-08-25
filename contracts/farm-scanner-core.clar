;; farm-scanner-core
;; 
;; This contract provides a decentralized platform for agricultural monitoring
;; and crop health tracking, utilizing blockchain technology to:
;; - Register and verify farm profiles
;; - Track crop growth stages and health metrics
;; - Enable secure data sharing between farmers and agricultural experts
;; - Generate personalized farm management recommendations

;; ---------- Error Constants ----------

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-FARM-ALREADY-EXISTS (err u101))
(define-constant ERR-FARM-NOT-FOUND (err u102))
(define-constant ERR-EXPERT-ALREADY-VERIFIED (err u103))
(define-constant ERR-EXPERT-NOT-VERIFIED (err u104))
(define-constant ERR-ANALYSIS-NOT-FOUND (err u105))
(define-constant ERR-INVALID-CROP-TYPE (err u106))
(define-constant ERR-INVALID-HEALTH-METRIC (err u107))
(define-constant ERR-INVALID-CONDITION (err u108))
(define-constant ERR-INVALID-WEATHER-DATA (err u109))
(define-constant ERR-INVALID-RATING (err u110))
(define-constant ERR-RECOMMENDATION-NOT-FOUND (err u111))
(define-constant ERR-ALREADY-RATED (err u112))

;; ---------- Data Maps and Variables ----------

;; Contract administrator who can verify agricultural experts
(define-data-var contract-admin principal tx-sender)

;; Valid crop types
(define-data-var valid-crop-types (list 10 (string-ascii 50)) 
  (list "wheat" "corn" "rice" "soybeans" "potatoes" "tomatoes"))

;; Valid health metrics
(define-data-var valid-health-metrics (list 10 (string-ascii 50)) 
  (list "soil-moisture" "pest-presence" "nutrient-levels" "leaf-color" "growth-rate"))

;; Valid agricultural goals
(define-data-var valid-farm-goals (list 10 (string-ascii 50)) 
  (list "yield-optimization" "sustainability" "pest-management" "water-conservation"))

;; Farm profiles storing agricultural information
(define-map farm-profiles
  { farm-owner: principal }
  {
    crop-type: (string-ascii 50),
    farm-size: uint,
    location: {
      latitude: int,
      longitude: int
    },
    health-metrics: (list 5 (string-ascii 50)),
    goals: (list 5 (string-ascii 50)),
    registration-time: uint
  }
)

;; Verified agricultural experts/agronomists
(define-map verified-experts
  { expert: principal }
  {
    verification-time: uint,
    credentials: (string-utf8 500),
    reputation-score: uint
  }
)

;; Crop analysis and health tracking templates
(define-map crop-analysis-templates
  { analysis-id: uint }
  {
    expert: principal,
    name: (string-utf8 100),
    description: (string-utf8 500),
    crop-types: (list 5 (string-ascii 50)),
    conditions: (list 5 {
      metric: (string-ascii 50),
      min-value: int,
      max-value: int
    }),
    weather-conditions: {
      min-temp: int,
      max-temp: int,
      min-humidity: uint,
      max-humidity: uint,
      max-uv-index: uint
    },
    recommended-actions: (list 10 {
      action-order: uint,
      action-type: (string-ascii 50),
      instructions: (string-utf8 200)
    }),
    creation-time: uint,
    rating-count: uint,
    average-rating: uint
  }
)

;; Personalized farm management recommendations
(define-map farm-recommendations
  { recommendation-id: uint }
  {
    farm-owner: principal,
    analysis-id: uint,
    weather-data: {
      temperature: int,
      humidity: uint,
      uv-index: uint,
      timestamp: uint
    },
    recommendation-time: uint,
    has-feedback: bool
  }
)

;; Expert feedback on farm management
(define-map expert-feedback
  { recommendation-id: uint }
  {
    expert: principal,
    rating: uint,
    comments: (optional (string-utf8 300)),
    feedback-time: uint
  }
)

;; Counters for generating IDs
(define-data-var next-analysis-id uint u1)
(define-data-var next-recommendation-id uint u1)

;; ---------- Private Functions ----------

;; Check if the caller is a verified expert
(define-private (is-verified-expert (caller principal))
  (is-some (map-get? verified-experts { expert: caller }))
)

;; Update expert reputation based on rating
(define-private (update-expert-reputation (expert principal) (rating uint))
  (let (
    (expert-data (unwrap-panic (map-get? verified-experts { expert: expert })))
    (current-score (get reputation-score expert-data))
    ;; Simple weighted average: new score is 90% old score + 10% new rating
    (new-score (+ (* u9 (/ current-score u10)) (/ rating u10)))
  )
  (map-set verified-experts
    { expert: expert }
    (merge expert-data { reputation-score: new-score })
  ))
)

;; Update analysis rating based on feedback
(define-private (update-analysis-rating (analysis-id uint) (rating uint))
  (let (
    (analysis (unwrap-panic (map-get? crop-analysis-templates { analysis-id: analysis-id })))
    (current-count (get rating-count analysis))
    (current-avg (get average-rating analysis))
    (new-count (+ current-count u1))
    (new-avg (if (is-eq current-count u0)
      rating
      ;; Calculate new average
      (/ (+ (* current-avg current-count) rating) new-count)
    ))
  )
  (map-set crop-analysis-templates
    { analysis-id: analysis-id }
    (merge analysis {
      rating-count: new-count,
      average-rating: new-avg
    })
  ))
)

;; Check if weather conditions match analysis requirements
(define-private (weather-matches-analysis? 
  (weather-data { temperature: int, humidity: uint, uv-index: uint, timestamp: uint })
  (analysis-conditions { min-temp: int, max-temp: int, min-humidity: uint, max-humidity: uint, max-uv-index: uint }))
  (and
    (>= (get temperature weather-data) (get min-temp analysis-conditions))
    (<= (get temperature weather-data) (get max-temp analysis-conditions))
    (>= (get humidity weather-data) (get min-humidity analysis-conditions))
    (<= (get humidity weather-data) (get max-humidity analysis-conditions))
    (<= (get uv-index weather-data) (get max-uv-index analysis-conditions))
  )
)

;; ---------- Read-Only Functions ----------

;; Get farm profile information
(define-read-only (get-farm-profile (farm-owner principal))
  (map-get? farm-profiles { farm-owner: farm-owner })
)

;; Check if a farm is registered
(define-read-only (is-farm-registered (farm-owner principal))
  (is-some (map-get? farm-profiles { farm-owner: farm-owner }))
)

;; Get expert verification status and reputation
(define-read-only (get-expert-info (expert principal))
  (map-get? verified-experts { expert: expert })
)

;; Get crop analysis template details
(define-read-only (get-crop-analysis-template (analysis-id uint))
  (map-get? crop-analysis-templates { analysis-id: analysis-id })
)

;; Get farm recommendation details
(define-read-only (get-farm-recommendation (recommendation-id uint))
  (map-get? farm-recommendations { recommendation-id: recommendation-id })
)

;; Get feedback for a recommendation
(define-read-only (get-recommendation-feedback (recommendation-id uint))
  (map-get? expert-feedback { recommendation-id: recommendation-id })
)

;; Get all valid crop types
(define-read-only (get-valid-crop-types)
  (var-get valid-crop-types)
)

;; Get all valid health metrics
(define-read-only (get-valid-health-metrics)
  (var-get valid-health-metrics)
)

;; Get all valid farm management goals
(define-read-only (get-valid-farm-goals)
  (var-get valid-farm-goals)
)

;; ---------- Public Functions ----------

;; Update contract administrator
(define-public (set-contract-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-NOT-AUTHORIZED)
    (ok (var-set contract-admin new-admin))
  )
)

;; Verify an agricultural expert (only contract admin can do this)
(define-public (verify-expert (expert principal) (credentials (string-utf8 500)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-verified-expert expert)) ERR-EXPERT-ALREADY-VERIFIED)
    
    (ok (map-set verified-experts
      { expert: expert }
      {
        verification-time: block-height,
        credentials: credentials,
        reputation-score: u80  ;; Start with 80/100 reputation
      }
    ))
  )
)

;; Generate a personalized farm management recommendation
(define-public (generate-recommendation
  (temperature int)
  (humidity uint)
  (uv-index uint))
  (let (
    (sender tx-sender)
    (weather-data {
      temperature: temperature,
      humidity: humidity,
      uv-index: uv-index,
      timestamp: block-height
    })
    (recommendation-id (var-get next-recommendation-id))
  )
    (asserts! (is-farm-registered sender) ERR-FARM-NOT-FOUND)
    
    ;; Simple validation of weather data
    (asserts! (and (>= temperature (- 50)) (<= temperature 50)) ERR-INVALID-WEATHER-DATA)
    (asserts! (and (>= humidity u0) (<= humidity u100)) ERR-INVALID-WEATHER-DATA)
    (asserts! (and (>= uv-index u0) (<= uv-index u12)) ERR-INVALID-WEATHER-DATA)
    
    ;; For demonstration purposes, we're choosing analysis ID 1
    ;; In a real implementation, we would scan all analyses to find the best match
    ;; based on weather conditions and farm profile
    (asserts! (is-some (get-crop-analysis-template u1)) ERR-ANALYSIS-NOT-FOUND)
    
    ;; Create the recommendation
    (map-set farm-recommendations
      { recommendation-id: recommendation-id }
      {
        farm-owner: sender,
        analysis-id: u1,
        weather-data: weather-data,
        recommendation-time: block-height,
        has-feedback: false
      }
    )
    
    ;; Increment recommendation ID counter
    (var-set next-recommendation-id (+ recommendation-id u1))
    
    (ok recommendation-id)
  )
)

;; Find best matching crop analysis for farm based on current weather
(define-public (find-best-analysis
  (temperature int)
  (humidity uint)
  (uv-index uint))
  (let (
    (sender tx-sender)
    (farm-data (unwrap! (get-farm-profile sender) ERR-FARM-NOT-FOUND))
    (weather-data {
      temperature: temperature,
      humidity: humidity,
      uv-index: uv-index,
      timestamp: block-height
    })
    ;; In a real implementation, this would scan all crop analysis templates
    ;; and find optimal matches using an algorithm
    ;; For demonstration purposes, we'll just return analysis ID 1 if it exists
    (analysis-id u1)
  )
    (asserts! (is-some (get-crop-analysis-template analysis-id)) ERR-ANALYSIS-NOT-FOUND)
    (ok analysis-id)
  )
)

;; Submit feedback for a recommendation
(define-public (submit-feedback
  (recommendation-id uint)
  (rating uint)
  (comments (optional (string-utf8 300))))
  (let (
    (sender tx-sender)
    (recommendation (unwrap! (map-get? farm-recommendations { recommendation-id: recommendation-id }) ERR-RECOMMENDATION-NOT-FOUND))
  )
    ;; Validate that the feedback comes from the recommendation recipient
    (asserts! (is-eq sender (get farm-owner recommendation)) ERR-NOT-AUTHORIZED)
    
    ;; Check that the recommendation hasn't already been rated
    (asserts! (not (get has-feedback recommendation)) ERR-ALREADY-RATED)
    
    ;; Validate rating (1-100 scale)
    (asserts! (and (>= rating u1) (<= rating u100)) ERR-INVALID-RATING)
    
    ;; Get the analysis data
    (let (
      (analysis-id (get analysis-id recommendation))
      (analysis (unwrap! (map-get? crop-analysis-templates { analysis-id: analysis-id }) ERR-ANALYSIS-NOT-FOUND))
      (expert (get expert analysis))
    )
      ;; Update the farm recommendation to mark it as having feedback
      (map-set farm-recommendations
        { recommendation-id: recommendation-id }
        (merge recommendation { has-feedback: true })
      )
      
      ;; Store the feedback
      (map-set expert-feedback
        { recommendation-id: recommendation-id }
        {
          expert: sender,
          rating: rating,
          comments: comments,
          feedback-time: block-height
        }
      )
      
      ;; Update the analysis's rating
      (update-analysis-rating analysis-id rating)
      
      ;; Update the expert's reputation
      (update-expert-reputation expert rating)
      
      (ok true)
    )
  )
)