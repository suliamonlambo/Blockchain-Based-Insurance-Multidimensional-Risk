;; Insurer Verification Contract
;; Validates and manages multidimensional risk insurance providers

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_VERIFIED (err u101))
(define-constant ERR_NOT_FOUND (err u102))
(define-constant ERR_INVALID_LICENSE (err u103))

;; Data Variables
(define-data-var next-insurer-id uint u1)

;; Data Maps
(define-map insurers
  { insurer-id: uint }
  {
    principal: principal,
    name: (string-ascii 100),
    license-number: (string-ascii 50),
    verification-status: bool,
    risk-categories: (list 10 (string-ascii 50)),
    capital-requirement: uint,
    created-at: uint
  }
)

(define-map insurer-principals
  { principal: principal }
  { insurer-id: uint }
)

;; Public Functions

;; Register a new insurer
(define-public (register-insurer
  (name (string-ascii 100))
  (license-number (string-ascii 50))
  (risk-categories (list 10 (string-ascii 50)))
  (capital-requirement uint))
  (let ((insurer-id (var-get next-insurer-id)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? insurer-principals { principal: tx-sender })) ERR_ALREADY_VERIFIED)

    (map-set insurers
      { insurer-id: insurer-id }
      {
        principal: tx-sender,
        name: name,
        license-number: license-number,
        verification-status: false,
        risk-categories: risk-categories,
        capital-requirement: capital-requirement,
        created-at: block-height
      }
    )

    (map-set insurer-principals
      { principal: tx-sender }
      { insurer-id: insurer-id }
    )

    (var-set next-insurer-id (+ insurer-id u1))
    (ok insurer-id)
  )
)

;; Verify an insurer
(define-public (verify-insurer (insurer-id uint))
  (let ((insurer-data (unwrap! (map-get? insurers { insurer-id: insurer-id }) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

    (map-set insurers
      { insurer-id: insurer-id }
      (merge insurer-data { verification-status: true })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get insurer details
(define-read-only (get-insurer (insurer-id uint))
  (map-get? insurers { insurer-id: insurer-id })
)

;; Check if principal is verified insurer
(define-read-only (is-verified-insurer (principal-address principal))
  (match (map-get? insurer-principals { principal: principal-address })
    insurer-record
      (match (map-get? insurers { insurer-id: (get insurer-id insurer-record) })
        insurer-data (get verification-status insurer-data)
        false
      )
    false
  )
)

;; Get insurer ID by principal
(define-read-only (get-insurer-id (principal-address principal))
  (map-get? insurer-principals { principal: principal-address })
)
