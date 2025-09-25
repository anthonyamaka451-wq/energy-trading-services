(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-insufficient-collateral (err u102))
(define-constant err-contract-expired (err u103))
(define-constant err-unauthorized-trader (err u104))

(define-map market-data
  { commodity-type: (string-ascii 30) }
  {
    current-price: uint,
    volume: uint,
    last-updated: uint,
    volatility-index: uint,
    market-trend: (string-ascii 20)
  }
)

(define-map trading-contracts
  { contract-id: uint }
  {
    buyer: principal,
    seller: principal,
    commodity-type: (string-ascii 30),
    quantity: uint,
    price-per-unit: uint,
    delivery-date: uint,
    status: (string-ascii 20),
    created-date: uint
  }
)

(define-map risk-assessments
  { assessment-id: uint }
  {
    contract-id: uint,
    risk-score: uint,
    risk-factors: (string-ascii 200),
    assessor: principal,
    assessment-date: uint,
    approved: bool
  }
)

(define-map settlements
  { settlement-id: uint }
  {
    contract-id: uint,
    settlement-amount: uint,
    settlement-date: uint,
    fees-collected: uint,
    status: (string-ascii 20)
  }
)

(define-map trader-profiles
  { trader: principal }
  {
    reputation-score: uint,
    total-trades: uint,
    active-contracts: uint,
    verified: bool
  }
)

(define-data-var next-contract-id uint u1)
(define-data-var next-assessment-id uint u1)
(define-data-var next-settlement-id uint u1)

(define-public (update-market-data (commodity-type (string-ascii 30)) (current-price uint) (volume uint) (volatility-index uint) (market-trend (string-ascii 20)))
  (if (is-eq tx-sender contract-owner)
    (ok (map-set market-data
      { commodity-type: commodity-type }
      {
        current-price: current-price,
        volume: volume,
        last-updated: stacks-block-height,
        volatility-index: volatility-index,
        market-trend: market-trend
      }
    ))
    err-owner-only
  )
)

(define-public (create-trading-contract (seller principal) (commodity-type (string-ascii 30)) (quantity uint) (price-per-unit uint) (delivery-date uint))
  (let ((contract-id (var-get next-contract-id)))
    (begin
      (map-set trading-contracts
        { contract-id: contract-id }
        {
          buyer: tx-sender,
          seller: seller,
          commodity-type: commodity-type,
          quantity: quantity,
          price-per-unit: price-per-unit,
          delivery-date: delivery-date,
          status: "pending",
          created-date: stacks-block-height
        }
      )
      (var-set next-contract-id (+ contract-id u1))
      (ok contract-id)
    )
  )
)

(define-public (conduct-risk-assessment (contract-id uint) (risk-score uint) (risk-factors (string-ascii 200)))
  (if (is-eq tx-sender contract-owner)
    (let ((assessment-id (var-get next-assessment-id)))
      (begin
        (map-set risk-assessments
          { assessment-id: assessment-id }
          {
            contract-id: contract-id,
            risk-score: risk-score,
            risk-factors: risk-factors,
            assessor: tx-sender,
            assessment-date: stacks-block-height,
            approved: (<= risk-score u70)
          }
        )
        (var-set next-assessment-id (+ assessment-id u1))
        (ok assessment-id)
      )
    )
    err-owner-only
  )
)

(define-public (approve-contract (contract-id uint))
  (let ((contract (map-get? trading-contracts { contract-id: contract-id })))
    (match contract
      contract-data
      (if (or (is-eq tx-sender (get buyer contract-data)) (is-eq tx-sender (get seller contract-data)))
        (begin
          (map-set trading-contracts
            { contract-id: contract-id }
            (merge contract-data { status: "active" })
          )
          (ok true)
        )
        err-unauthorized-trader
      )
      err-not-found
    )
  )
)

(define-public (process-settlement (contract-id uint) (settlement-amount uint) (fees uint))
  (if (is-eq tx-sender contract-owner)
    (let ((settlement-id (var-get next-settlement-id)))
      (begin
        (map-set settlements
          { settlement-id: settlement-id }
          {
            contract-id: contract-id,
            settlement-amount: settlement-amount,
            settlement-date: stacks-block-height,
            fees-collected: fees,
            status: "completed"
          }
        )
        (var-set next-settlement-id (+ settlement-id u1))
        (ok settlement-id)
      )
    )
    err-owner-only
  )
)

(define-public (register-trader)
  (ok (map-set trader-profiles
    { trader: tx-sender }
    {
      reputation-score: u100,
      total-trades: u0,
      active-contracts: u0,
      verified: false
    }
  ))
)

(define-public (verify-trader (trader principal))
  (if (is-eq tx-sender contract-owner)
    (let ((profile (map-get? trader-profiles { trader: trader })))
      (match profile
        profile-data
        (begin
          (map-set trader-profiles
            { trader: trader }
            (merge profile-data { verified: true })
          )
          (ok true)
        )
        err-not-found
      )
    )
    err-owner-only
  )
)

(define-read-only (get-market-data (commodity-type (string-ascii 30)))
  (map-get? market-data { commodity-type: commodity-type })
)

(define-read-only (get-trading-contract (contract-id uint))
  (map-get? trading-contracts { contract-id: contract-id })
)

(define-read-only (get-risk-assessment (assessment-id uint))
  (map-get? risk-assessments { assessment-id: assessment-id })
)

(define-read-only (get-settlement (settlement-id uint))
  (map-get? settlements { settlement-id: settlement-id })
)

(define-read-only (get-trader-profile (trader principal))
  (map-get? trader-profiles { trader: trader })
)

