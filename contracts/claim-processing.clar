;; Claim Processing Contract
;; Manages multidimensional insurance claims

;; Constants
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_CLAIM_NOT_FOUND (err u401))
(define-constant ERR_INVALID_AMOUNT (err u402))
(define-constant ERR_POLICY_INACTIVE (err u403))
(define-constant ERR_CLAIM_EXISTS (err u404))
(define-constant ERR_INVALID_STATUS (err u405))

;; Data Variables
(define-data-var next-claim-id uint u1)

;; Data Maps
(define-map claims
  { claim-id: uint }
  {
    policy-id: uint,
    claimant: principal,
    insurer: principal,
    claim-amount: uint,
    incident-date: uint,
    claim-date: uint,
    description: (string-ascii 500),
    evidence-hash: (string-ascii 64),
    status: (string-ascii 20),
    assessor: (optional principal),
    settlement-amount: uint,
    settlement-date: (optional uint)
  }
)

(define-map policy-claims
  { policy-id: uint }
  { claim-ids: (list 50 uint) }
)

(define-map claim-assessments
  { claim-id: uint }
  {
    assessor: principal,
    assessment-date: uint,
    recommended-amount: uint,
    assessment-notes: (string-ascii 500)
  }
)

;; Public Functions

;; Submit new claim
(define-public (submit-claim
  (policy-id uint)
  (claim-amount uint)
  (incident-date uint)
  (description (string-ascii 500))
  (evidence-hash (string-ascii 64)))
  (let ((claim-id (var-get next-claim-id))
        (existing-claims (default-to { claim-ids: (list) } (map-get? policy-claims { policy-id: policy-id }))))

    (asserts! (> claim-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (<= incident-date block-height) ERR_INVALID_AMOUNT)

    (map-set claims
      { claim-id: claim-id }
      {
        policy-id: policy-id,
        claimant: tx-sender,
        insurer: tx-sender, ;; This should be retrieved from policy
        claim-amount: claim-amount,
        incident-date: incident-date,
        claim-date: block-height,
        description: description,
        evidence-hash: evidence-hash,
        status: "submitted",
        assessor: none,
        settlement-amount: u0,
        settlement-date: none
      }
    )

    (map-set policy-claims
      { policy-id: policy-id }
      { claim-ids: (unwrap! (as-max-len? (append (get claim-ids existing-claims) claim-id) u50) ERR_CLAIM_EXISTS) }
    )

    (var-set next-claim-id (+ claim-id u1))
    (ok claim-id)
  )
)

;; Assign assessor to claim
(define-public (assign-assessor (claim-id uint) (assessor principal))
  (let ((claim (unwrap! (map-get? claims { claim-id: claim-id }) ERR_CLAIM_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get insurer claim)) ERR_UNAUTHORIZED)

    (map-set claims
      { claim-id: claim-id }
      (merge claim {
        assessor: (some assessor),
        status: "under-assessment"
      })
    )
    (ok true)
  )
)

;; Submit claim assessment
(define-public (submit-assessment
  (claim-id uint)
  (recommended-amount uint)
  (assessment-notes (string-ascii 500)))
  (let ((claim (unwrap! (map-get? claims { claim-id: claim-id }) ERR_CLAIM_NOT_FOUND)))
    (asserts! (is-eq (some tx-sender) (get assessor claim)) ERR_UNAUTHORIZED)

    (map-set claim-assessments
      { claim-id: claim-id }
      {
        assessor: tx-sender,
        assessment-date: block-height,
        recommended-amount: recommended-amount,
        assessment-notes: assessment-notes
      }
    )

    (map-set claims
      { claim-id: claim-id }
      (merge claim { status: "assessed" })
    )
    (ok true)
  )
)

;; Approve claim
(define-public (approve-claim (claim-id uint) (settlement-amount uint))
  (let ((claim (unwrap! (map-get? claims { claim-id: claim-id }) ERR_CLAIM_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get insurer claim)) ERR_UNAUTHORIZED)
    (asserts! (> settlement-amount u0) ERR_INVALID_AMOUNT)

    (map-set claims
      { claim-id: claim-id }
      (merge claim {
        status: "approved",
        settlement-amount: settlement-amount,
        settlement-date: (some block-height)
      })
    )
    (ok true)
  )
)

;; Reject claim
(define-public (reject-claim (claim-id uint))
  (let ((claim (unwrap! (map-get? claims { claim-id: claim-id }) ERR_CLAIM_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get insurer claim)) ERR_UNAUTHORIZED)

    (map-set claims
      { claim-id: claim-id }
      (merge claim {
        status: "rejected",
        settlement-date: (some block-height)
      })
    )
    (ok true)
  )
)

;; Update claim status
(define-public (update-claim-status (claim-id uint) (new-status (string-ascii 20)))
  (let ((claim (unwrap! (map-get? claims { claim-id: claim-id }) ERR_CLAIM_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get insurer claim)) ERR_UNAUTHORIZED)

    (map-set claims
      { claim-id: claim-id }
      (merge claim { status: new-status })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get claim details
(define-read-only (get-claim (claim-id uint))
  (map-get? claims { claim-id: claim-id })
)

;; Get claims for policy
(define-read-only (get-policy-claims (policy-id uint))
  (map-get? policy-claims { policy-id: policy-id })
)

;; Get claim assessment
(define-read-only (get-claim-assessment (claim-id uint))
  (map-get? claim-assessments { claim-id: claim-id })
)

;; Check if claim is pending
(define-read-only (is-claim-pending (claim-id uint))
  (match (map-get? claims { claim-id: claim-id })
    claim
      (or
        (is-eq (get status claim) "submitted")
        (is-eq (get status claim) "under-assessment")
        (is-eq (get status claim) "assessed")
      )
    false
  )
)

;; Get claims by status
(define-read-only (get-claim-status (claim-id uint))
  (match (map-get? claims { claim-id: claim-id })
    claim (some (get status claim))
    none
  )
)
