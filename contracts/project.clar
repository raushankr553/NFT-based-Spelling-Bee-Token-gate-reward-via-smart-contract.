;; NFT-based Spelling Bee Smart Contract
;; Token gate participation and reward system for spelling competitions

;; Define the NFT for participation tickets
(define-non-fungible-token spelling-bee-ticket uint)

;; Define reward token
(define-fungible-token spelling-reward)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-already-participated (err u102))
(define-constant err-invalid-score (err u103))
(define-constant err-no-ticket (err u104))
(define-constant err-insufficient-funds (err u105))

;; Competition parameters
(define-data-var ticket-price uint u1000000) ;; 1 STX in microSTX
(define-data-var reward-per-correct-word uint u100) ;; 100 reward tokens per correct word
(define-data-var next-ticket-id uint u1)

;; Player data
(define-map player-scores principal uint)
(define-map player-participation principal bool)

;; Function 1: Mint participation ticket (Token Gate)
;; Players must pay STX to get an NFT ticket to participate
(define-public (mint-participation-ticket)
  (let ((ticket-id (var-get next-ticket-id))
        (price (var-get ticket-price)))
    (begin
      ;; Check if player already has a ticket for this round
      (asserts! (is-none (map-get? player-participation tx-sender)) err-already-participated)
      
      ;; Transfer STX payment to contract
      (try! (stx-transfer? price tx-sender (as-contract tx-sender)))
      
      ;; Mint NFT ticket to player
      (try! (nft-mint? spelling-bee-ticket ticket-id tx-sender))
      
      ;; Mark player as participated
      (map-set player-participation tx-sender true)
      
      ;; Increment ticket ID for next participant
      (var-set next-ticket-id (+ ticket-id u1))
      
      ;; Print event for tracking
      (print {
        event: "ticket-minted",
        player: tx-sender,
        ticket-id: ticket-id,
        price-paid: price
      })
      
      (ok ticket-id))))

;; Function 2: Submit spelling score and claim rewards
;; Players with valid tickets can submit their scores and receive reward tokens
(define-public (submit-score-and-claim-reward (correct-words uint) (ticket-id uint))
  (let ((reward-amount (* correct-words (var-get reward-per-correct-word))))
    (begin
      ;; Verify player owns the ticket NFT
      (asserts! (is-eq (some tx-sender) (nft-get-owner? spelling-bee-ticket ticket-id)) err-no-ticket)
      
      ;; Verify player has participated (has ticket)
      (asserts! (is-some (map-get? player-participation tx-sender)) err-not-authorized)
      
      ;; Validate score (reasonable range: 0-50 words)
      (asserts! (<= correct-words u50) err-invalid-score)
      
      ;; Record player's score
      (map-set player-scores tx-sender correct-words)
      
      ;; Mint reward tokens based on performance
      (if (> reward-amount u0)
        (try! (ft-mint? spelling-reward reward-amount tx-sender))
        true)
      
      ;; Print event for tracking
      (print {
        event: "score-submitted",
        player: tx-sender,
        ticket-id: ticket-id,
        correct-words: correct-words,
        rewards-earned: reward-amount
      })
      
      (ok {
        score: correct-words,
        rewards-earned: reward-amount
      }))))

;; Read-only functions for querying data

(define-read-only (get-player-score (player principal))
  (map-get? player-scores player))

(define-read-only (has-participation-ticket (player principal))
  (is-some (map-get? player-participation player)))

(define-read-only (get-ticket-price)
  (var-get ticket-price))

(define-read-only (get-reward-rate)
  (var-get reward-per-correct-word))

(define-read-only (get-next-ticket-id)
  (var-get next-ticket-id))

(define-read-only (get-reward-balance (player principal))
  (ft-get-balance spelling-reward player))

;; Owner functions for contract management

(define-public (set-ticket-price (new-price uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set ticket-price new-price)
    (ok true)))

(define-public (set-reward-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set reward-per-correct-word new-rate)
    (ok true)))