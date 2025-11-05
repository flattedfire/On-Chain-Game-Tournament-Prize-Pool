(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_ALREADY_EXISTS (err u409))
(define-constant ERR_INVALID_AMOUNT (err u400))
(define-constant ERR_TOURNAMENT_ACTIVE (err u403))
(define-constant ERR_TOURNAMENT_ENDED (err u410))
(define-constant ERR_ALREADY_JOINED (err u411))
(define-constant ERR_NOT_PARTICIPANT (err u412))
(define-constant ERR_INSUFFICIENT_BALANCE (err u413))
(define-constant ERR_PRIZE_ALREADY_CLAIMED (err u414))
(define-constant ERR_NO_PRIZE (err u415))
(define-constant ERR_NO_SPONSORSHIP (err u416))

(define-constant CONTRACT_OWNER tx-sender)

(define-data-var tournament-counter uint u0)

(define-map tournaments uint {
    organizer: principal,
    name: (string-ascii 50),
    entry-fee: uint,
    total-pool: uint,
    sponsorship-pool: uint,
    status: (string-ascii 20),
    participants: (list 100 principal),
    participant-count: uint,
    winners: (list 10 principal),
    prize-distribution: (list 10 uint),
    created-at: uint,
    ended-at: (optional uint)
})

(define-map participant-tournaments {participant: principal, tournament-id: uint} {
    joined-at: uint,
    prize-claimed: bool,
    prize-amount: uint
})

(define-map tournament-sponsors {tournament-id: uint, sponsor: principal} {
    amount: uint,
    sponsored-at: uint,
    withdrawn: bool
})

(define-map tournament-delegates {tournament-id: uint, delegate: principal} bool)

(define-map player-statistics principal {
    tournaments-joined: uint,
    tournaments-won: uint,
    total-prizes-claimed: uint,
    total-entry-fees-paid: uint,
    win-rate: uint,
    net-profit: uint,
    last-active: uint
})

(define-public (create-tournament (name (string-ascii 50)) (entry-fee uint))
    (let ((tournament-id (+ (var-get tournament-counter) u1)))
        (asserts! (> entry-fee u0) ERR_INVALID_AMOUNT)
        (map-set tournaments tournament-id {
            organizer: tx-sender,
            name: name,
            entry-fee: entry-fee,
            total-pool: u0,
            sponsorship-pool: u0,
            status: "open",
            participants: (list),
            participant-count: u0,
            winners: (list),
            prize-distribution: (list),
            created-at: stacks-block-height,
            ended-at: none
        })
        (var-set tournament-counter tournament-id)
        (ok tournament-id)
    )
)

(define-public (join-tournament (tournament-id uint))
    (let ((tournament-data (unwrap! (map-get? tournaments tournament-id) ERR_NOT_FOUND))
          (entry-fee (get entry-fee tournament-data))
          (current-participants (get participants tournament-data))
          (participant-count (get participant-count tournament-data)))
        (asserts! (is-eq (get status tournament-data) "open") ERR_TOURNAMENT_ENDED)
        (asserts! (is-none (map-get? participant-tournaments {participant: tx-sender, tournament-id: tournament-id})) ERR_ALREADY_JOINED)
        (asserts! (< participant-count u100) ERR_TOURNAMENT_ACTIVE)
        
        (try! (stx-transfer? entry-fee tx-sender (as-contract tx-sender)))
        
        (map-set participant-tournaments {participant: tx-sender, tournament-id: tournament-id} {
            joined-at: stacks-block-height,
            prize-claimed: false,
            prize-amount: u0
        })
        
        (map-set tournaments tournament-id (merge tournament-data {
            participants: (unwrap! (as-max-len? (append current-participants tx-sender) u100) ERR_TOURNAMENT_ACTIVE),
            participant-count: (+ participant-count u1),
            total-pool: (+ (get total-pool tournament-data) entry-fee)
        }))
        
        (update-player-join-stats tx-sender entry-fee)
        
        (ok true)
    )
)

(define-public (end-tournament (tournament-id uint) (winners (list 10 principal)))
    (let ((tournament-data (unwrap! (map-get? tournaments tournament-id) ERR_NOT_FOUND))
          (total-pool (get total-pool tournament-data))
          (sponsorship-pool (get sponsorship-pool tournament-data))
          (combined-pool (+ total-pool sponsorship-pool))
          (organizer-fee (/ combined-pool u20))
          (distributable-pool (- combined-pool organizer-fee))
          (winners-count (len winners))
          (prize-per-winner (if (> winners-count u0) (/ distributable-pool winners-count) u0)))
        (asserts! (or (is-eq tx-sender (get organizer tournament-data)) (is-some (map-get? tournament-delegates {tournament-id: tournament-id, delegate: tx-sender}))) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status tournament-data) "open") ERR_TOURNAMENT_ENDED)
        (asserts! (> winners-count u0) ERR_INVALID_AMOUNT)
        (asserts! (<= winners-count u10) ERR_INVALID_AMOUNT)
        
        (unwrap! (distribute-equal-prizes tournament-id winners prize-per-winner) ERR_INVALID_AMOUNT)
        (try! (as-contract (stx-transfer? organizer-fee tx-sender (get organizer tournament-data))))
        
        (map-set tournaments tournament-id (merge tournament-data {
            status: "ended",
            winners: winners,
            prize-distribution: (list prize-per-winner),
            ended-at: (some stacks-block-height)
        }))
        
        (ok true)
    )
)

(define-private (distribute-equal-prizes (tournament-id uint) (winners (list 10 principal)) (prize-amount uint))
    (let ((winners-len (len winners)))
        (if (> winners-len u0)
            (begin
                (and 
                    (set-winner-prize tournament-id (element-at winners u0) prize-amount)
                    (set-winner-prize tournament-id (element-at winners u1) prize-amount)
                    (set-winner-prize tournament-id (element-at winners u2) prize-amount)
                    (set-winner-prize tournament-id (element-at winners u3) prize-amount)
                    (set-winner-prize tournament-id (element-at winners u4) prize-amount)
                    (set-winner-prize tournament-id (element-at winners u5) prize-amount)
                    (set-winner-prize tournament-id (element-at winners u6) prize-amount)
                    (set-winner-prize tournament-id (element-at winners u7) prize-amount)
                    (set-winner-prize tournament-id (element-at winners u8) prize-amount)
                    (set-winner-prize tournament-id (element-at winners u9) prize-amount)
                )
                (ok true)
            )
            (ok false)
        )
    )
)

(define-private (set-winner-prize (tournament-id uint) (winner-opt (optional principal)) (prize-amount uint))
    (match winner-opt
        winner
        (match (map-get? participant-tournaments {participant: winner, tournament-id: tournament-id})
            participant-data 
            (begin
                (map-set participant-tournaments 
                    {participant: winner, tournament-id: tournament-id}
                    (merge participant-data {prize-amount: prize-amount}))
                true)
            true)
        true
    )
)

(define-private (update-player-join-stats (player principal) (entry-fee uint))
    (let ((current-stats (default-to 
            {
                tournaments-joined: u0,
                tournaments-won: u0,
                total-prizes-claimed: u0,
                total-entry-fees-paid: u0,
                win-rate: u0,
                net-profit: u0,
                last-active: u0
            }
            (map-get? player-statistics player)))
          (new-tournaments-joined (+ (get tournaments-joined current-stats) u1))
          (new-entry-fees-paid (+ (get total-entry-fees-paid current-stats) entry-fee)))
        (map-set player-statistics player {
            tournaments-joined: new-tournaments-joined,
            tournaments-won: (get tournaments-won current-stats),
            total-prizes-claimed: (get total-prizes-claimed current-stats),
            total-entry-fees-paid: new-entry-fees-paid,
            win-rate: (calculate-win-rate (get tournaments-won current-stats) new-tournaments-joined),
            net-profit: (calculate-net-profit (get total-prizes-claimed current-stats) new-entry-fees-paid),
            last-active: stacks-block-height
        })
    )
)

(define-private (update-player-win-stats (player principal) (prize-amount uint))
    (let ((current-stats (default-to 
            {
                tournaments-joined: u0,
                tournaments-won: u0,
                total-prizes-claimed: u0,
                total-entry-fees-paid: u0,
                win-rate: u0,
                net-profit: u0,
                last-active: u0
            }
            (map-get? player-statistics player)))
          (new-tournaments-won (+ (get tournaments-won current-stats) u1))
          (new-prizes-claimed (+ (get total-prizes-claimed current-stats) prize-amount)))
        (map-set player-statistics player {
            tournaments-joined: (get tournaments-joined current-stats),
            tournaments-won: new-tournaments-won,
            total-prizes-claimed: new-prizes-claimed,
            total-entry-fees-paid: (get total-entry-fees-paid current-stats),
            win-rate: (calculate-win-rate new-tournaments-won (get tournaments-joined current-stats)),
            net-profit: (calculate-net-profit new-prizes-claimed (get total-entry-fees-paid current-stats)),
            last-active: stacks-block-height
        })
    )
)

(define-private (calculate-win-rate (wins uint) (total-tournaments uint))
    (if (> total-tournaments u0)
        (/ (* wins u100) total-tournaments)
        u0
    )
)

(define-private (calculate-net-profit (total-prizes uint) (total-fees uint))
    (if (>= total-prizes total-fees)
        (- total-prizes total-fees)
        u0
    )
)

(define-public (claim-prize (tournament-id uint))
    (let ((participant-data (unwrap! (map-get? participant-tournaments {participant: tx-sender, tournament-id: tournament-id}) ERR_NOT_PARTICIPANT))
          (tournament-data (unwrap! (map-get? tournaments tournament-id) ERR_NOT_FOUND))
          (prize-amount (get prize-amount participant-data)))
        (asserts! (is-eq (get status tournament-data) "ended") ERR_TOURNAMENT_ACTIVE)
        (asserts! (not (get prize-claimed participant-data)) ERR_PRIZE_ALREADY_CLAIMED)
        (asserts! (> prize-amount u0) ERR_NO_PRIZE)
        
        (try! (as-contract (stx-transfer? prize-amount tx-sender tx-sender)))
        
        (map-set participant-tournaments {participant: tx-sender, tournament-id: tournament-id} 
                 (merge participant-data {prize-claimed: true}))
        
        (update-player-win-stats tx-sender prize-amount)
        
        (ok prize-amount)
    )
)

(define-public (cancel-tournament (tournament-id uint))
    (let ((tournament-data (unwrap! (map-get? tournaments tournament-id) ERR_NOT_FOUND))
          (participants (get participants tournament-data))
          (entry-fee (get entry-fee tournament-data)))
        (asserts! (or (is-eq tx-sender (get organizer tournament-data)) (is-some (map-get? tournament-delegates {tournament-id: tournament-id, delegate: tx-sender}))) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status tournament-data) "open") ERR_TOURNAMENT_ENDED)
        
        (unwrap! (refund-participants tournament-id participants entry-fee) ERR_INSUFFICIENT_BALANCE)
        
        (map-set tournaments tournament-id (merge tournament-data {
            status: "cancelled",
            ended-at: (some stacks-block-height)
        }))
        
        (ok true)
    )
)

(define-private (refund-participants (tournament-id uint) (participants (list 100 principal)) (entry-fee uint))
    (fold refund-single-participant participants (ok entry-fee))
)

(define-private (refund-single-participant (participant principal) (acc (response uint uint)))
    (match acc
        fee-amount 
        (begin
            (try! (as-contract (stx-transfer? fee-amount tx-sender participant)))
            (ok fee-amount))
        error-val (err error-val)
    )
)

(define-public (withdraw-unclaimed-funds (tournament-id uint))
    (let ((tournament-data (unwrap! (map-get? tournaments tournament-id) ERR_NOT_FOUND)))
        (asserts! (or (is-eq tx-sender (get organizer tournament-data)) (is-some (map-get? tournament-delegates {tournament-id: tournament-id, delegate: tx-sender}))) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status tournament-data) "ended") ERR_TOURNAMENT_ACTIVE)
        (asserts! (> (- stacks-block-height (unwrap! (get ended-at tournament-data) ERR_NOT_FOUND)) u1000) ERR_TOURNAMENT_ACTIVE)
        
        (let ((contract-balance (stx-get-balance (as-contract tx-sender))))
            (try! (as-contract (stx-transfer? contract-balance tx-sender (get organizer tournament-data))))
            (ok contract-balance)
        )
    )
)

(define-public (authorize-delegate (tournament-id uint) (delegate principal))
    (let ((tournament-data (unwrap! (map-get? tournaments tournament-id) ERR_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get organizer tournament-data)) ERR_UNAUTHORIZED)
        (map-set tournament-delegates {tournament-id: tournament-id, delegate: delegate} true)
        (ok true)
    )
)

(define-public (revoke-delegate (tournament-id uint) (delegate principal))
    (let ((tournament-data (unwrap! (map-get? tournaments tournament-id) ERR_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get organizer tournament-data)) ERR_UNAUTHORIZED)
        (map-delete tournament-delegates {tournament-id: tournament-id, delegate: delegate})
        (ok true)
    )
)

(define-read-only (is-delegate (tournament-id uint) (delegate principal))
    (is-some (map-get? tournament-delegates {tournament-id: tournament-id, delegate: delegate}))
)

(define-public (sponsor-tournament (tournament-id uint) (amount uint))
    (let ((tournament-data (unwrap! (map-get? tournaments tournament-id) ERR_NOT_FOUND))
          (current-sponsorship-pool (get sponsorship-pool tournament-data)))
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (asserts! (is-eq (get status tournament-data) "open") ERR_TOURNAMENT_ENDED)
        
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        (map-set tournament-sponsors {tournament-id: tournament-id, sponsor: tx-sender} {
            amount: amount,
            sponsored-at: stacks-block-height,
            withdrawn: false
        })
        
        (map-set tournaments tournament-id (merge tournament-data {
            sponsorship-pool: (+ current-sponsorship-pool amount)
        }))
        
        (ok amount)
    )
)

(define-public (withdraw-sponsorship (tournament-id uint))
    (let ((tournament-data (unwrap! (map-get? tournaments tournament-id) ERR_NOT_FOUND))
          (sponsorship-data (unwrap! (map-get? tournament-sponsors {tournament-id: tournament-id, sponsor: tx-sender}) ERR_NO_SPONSORSHIP))
          (sponsorship-amount (get amount sponsorship-data))
          (current-sponsorship-pool (get sponsorship-pool tournament-data)))
        (asserts! (is-eq (get status tournament-data) "open") ERR_TOURNAMENT_ENDED)
        (asserts! (not (get withdrawn sponsorship-data)) ERR_ALREADY_EXISTS)
        
        (try! (as-contract (stx-transfer? sponsorship-amount tx-sender tx-sender)))
        
        (map-set tournament-sponsors {tournament-id: tournament-id, sponsor: tx-sender} 
                 (merge sponsorship-data {withdrawn: true}))
        
        (map-set tournaments tournament-id (merge tournament-data {
            sponsorship-pool: (- current-sponsorship-pool sponsorship-amount)
        }))
        
        (ok sponsorship-amount)
    )
)

(define-read-only (get-tournament (tournament-id uint))
    (map-get? tournaments tournament-id)
)

(define-read-only (get-participant-info (participant principal) (tournament-id uint))
    (map-get? participant-tournaments {participant: participant, tournament-id: tournament-id})
)

(define-read-only (get-tournament-count)
    (var-get tournament-counter)
)

(define-read-only (get-contract-balance)
    (stx-get-balance (as-contract tx-sender))
)

(define-read-only (is-tournament-participant (participant principal) (tournament-id uint))
    (is-some (map-get? participant-tournaments {participant: participant, tournament-id: tournament-id}))
)

(define-read-only (get-tournament-participants (tournament-id uint))
    (match (map-get? tournaments tournament-id)
        tournament-data (some (get participants tournament-data))
        none
    )
)

(define-read-only (get-tournament-winners (tournament-id uint))
    (match (map-get? tournaments tournament-id)
        tournament-data (some (get winners tournament-data))
        none
    )
)

(define-read-only (get-prize-pool (tournament-id uint))
    (match (map-get? tournaments tournament-id)
        tournament-data (some (get total-pool tournament-data))
        none
    )
)

(define-read-only (calculate-organizer-fee (tournament-id uint))
    (match (map-get? tournaments tournament-id)
        tournament-data 
        (let ((total-pool (get total-pool tournament-data))
              (sponsorship-pool (get sponsorship-pool tournament-data))
              (combined-pool (+ total-pool sponsorship-pool)))
            (some (/ combined-pool u20)))
        none
    )
)

(define-read-only (get-unclaimed-prizes (tournament-id uint))
    (let ((tournament-data (unwrap! (map-get? tournaments tournament-id) none))
          (winners (get winners tournament-data)))
        (some (fold count-unclaimed-prizes winners u0))
    )
)

(define-private (count-unclaimed-prizes (winner principal) (count uint))
    (let ((tournament-id u1))
        (match (map-get? participant-tournaments {participant: winner, tournament-id: tournament-id})
            participant-data 
            (if (not (get prize-claimed participant-data))
                (+ count u1)
                count)
            count
        )
    )
)

(define-read-only (get-sponsorship-pool (tournament-id uint))
    (match (map-get? tournaments tournament-id)
        tournament-data (some (get sponsorship-pool tournament-data))
        none
    )
)

(define-read-only (get-total-prize-pool (tournament-id uint))
    (match (map-get? tournaments tournament-id)
        tournament-data 
        (let ((total-pool (get total-pool tournament-data))
              (sponsorship-pool (get sponsorship-pool tournament-data)))
            (some (+ total-pool sponsorship-pool)))
        none
    )
)

(define-read-only (get-sponsor-info (tournament-id uint) (sponsor principal))
    (map-get? tournament-sponsors {tournament-id: tournament-id, sponsor: sponsor})
)

(define-read-only (get-player-statistics (player principal))
    (map-get? player-statistics player)
)

(define-read-only (get-player-win-rate (player principal))
    (match (map-get? player-statistics player)
        stats (some (get win-rate stats))
        none
    )
)

(define-read-only (get-player-net-profit (player principal))
    (match (map-get? player-statistics player)
        stats (some (get net-profit stats))
        none
    )
)

(define-read-only (get-player-total-wins (player principal))
    (match (map-get? player-statistics player)
        stats (some (get tournaments-won stats))
        none
    )
)

(define-read-only (get-player-total-tournaments (player principal))
    (match (map-get? player-statistics player)
        stats (some (get tournaments-joined stats))
        none
    )
)
