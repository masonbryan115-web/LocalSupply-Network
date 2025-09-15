;; Community Rewards Smart Contract
;; Loyalty system rewarding local purchasing and sustainable choices

;; Constants for error handling
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-USER-NOT-FOUND (err u404))
(define-constant ERR-BUSINESS-NOT-FOUND (err u404))
(define-constant ERR-INSUFFICIENT-POINTS (err u402))
(define-constant ERR-INVALID-AMOUNT (err u400))
(define-constant ERR-ALREADY-EXISTS (err u409))
(define-constant ERR-INVALID-TIER (err u405))
(define-constant ERR-REWARD-NOT-AVAILABLE (err u406))
(define-constant ERR-ACHIEVEMENT-NOT-FOUND (err u407))
(define-constant ERR-ALREADY-CLAIMED (err u408))

;; Contract owner (admin)
(define-constant contract-owner tx-sender)

;; Data variables
(define-data-var next-user-id uint u1)
(define-data-var next-business-id uint u1)
(define-data-var next-transaction-id uint u1)
(define-data-var next-achievement-id uint u1)
(define-data-var total-points-issued uint u0)
(define-data-var total-points-redeemed uint u0)
(define-data-var community-impact-score uint u0)

;; Membership tier constants
(define-constant TIER-BRONZE u1)
(define-constant TIER-SILVER u2)
(define-constant TIER-GOLD u3)
(define-constant TIER-PLATINUM u4)
(define-constant TIER-DIAMOND u5)

;; Point multipliers for sustainable actions
(define-constant LOCAL-PURCHASE-MULTIPLIER u10)
(define-constant ORGANIC-PURCHASE-MULTIPLIER u15)
(define-constant SEASONAL-PURCHASE-MULTIPLIER u12)
(define-constant BULK-PURCHASE-MULTIPLIER u8)
(define-constant REFERRAL-BONUS u50)

;; Achievement types
(define-constant ACHIEVEMENT-FIRST-PURCHASE u1)
(define-constant ACHIEVEMENT-LOCAL-CHAMPION u2)
(define-constant ACHIEVEMENT-ECO-WARRIOR u3)
(define-constant ACHIEVEMENT-COMMUNITY-BUILDER u4)
(define-constant ACHIEVEMENT-SEASONAL-SUPPORTER u5)

;; User account structure
(define-map users
    uint
    {
        wallet: principal,
        username: (string-ascii 50),
        email: (string-ascii 100),
        registration-date: uint,
        total-points: uint,
        available-points: uint,
        tier: uint,
        total-purchases: uint,
        local-purchases: uint,
        organic-purchases: uint,
        seasonal-purchases: uint,
        referrals-made: uint,
        community-score: uint,
        last-activity: uint,
        preferred-categories: (list 5 (string-ascii 30))
    }
)

;; Local business partners
(define-map partner-businesses
    uint
    {
        owner: principal,
        business-name: (string-ascii 100),
        category: (string-ascii 50),
        location: (string-ascii 100),
        description: (string-ascii 300),
        point-rate: uint,
        sustainability-rating: uint,
        registration-date: uint,
        total-transactions: uint,
        active: bool,
        special-offers: (list 3 (string-ascii 200))
    }
)

;; Purchase transactions for points
(define-map purchase-transactions
    uint
    {
        user-id: uint,
        business-id: uint,
        amount: uint,
        points-earned: uint,
        purchase-date: uint,
        is-local: bool,
        is-organic: bool,
        is-seasonal: bool,
        category: (string-ascii 50),
        sustainability-bonus: uint
    }
)

;; Achievement definitions
(define-map achievements
    uint
    {
        name: (string-ascii 100),
        description: (string-ascii 200),
        achievement-type: uint,
        points-reward: uint,
        requirement-value: uint,
        icon: (string-ascii 100),
        is-active: bool
    }
)

;; User achievements tracking
(define-map user-achievements
    { user-id: uint, achievement-id: uint }
    {
        unlocked-date: uint,
        claimed: bool,
        points-claimed: uint
    }
)

;; Reward redemption options
(define-map reward-options
    uint
    {
        name: (string-ascii 100),
        description: (string-ascii 200),
        points-cost: uint,
        business-id: (optional uint),
        category: (string-ascii 50),
        availability: uint,
        expiry-date: (optional uint),
        is-active: bool
    }
)

;; Tier benefits structure
(define-map tier-benefits
    uint
    {
        tier-name: (string-ascii 20),
        min-points: uint,
        point-multiplier: uint,
        special-benefits: (list 5 (string-ascii 100)),
        monthly-bonus: uint
    }
)

;; Community challenges
(define-map community-challenges
    uint
    {
        title: (string-ascii 100),
        description: (string-ascii 300),
        start-date: uint,
        end-date: uint,
        target-value: uint,
        current-progress: uint,
        reward-pool: uint,
        participants: uint,
        is-active: bool
    }
)

;; User mappings
(define-map user-wallets principal uint)
(define-map business-owners principal uint)

;; Read-only functions

;; Get user details
(define-read-only (get-user (user-id uint))
    (map-get? users user-id)
)

;; Get user by wallet
(define-read-only (get-user-by-wallet (wallet principal))
    (let
        (
            (user-id (map-get? user-wallets wallet))
        )
        (match user-id
            some-id (map-get? users some-id)
            none
        )
    )
)

;; Get business details
(define-read-only (get-business (business-id uint))
    (map-get? partner-businesses business-id)
)

;; Get user points balance
(define-read-only (get-user-points (user-id uint))
    (let
        (
            (user (map-get? users user-id))
        )
        (match user
            some-user (get available-points some-user)
            u0
        )
    )
)

;; Calculate points for purchase
(define-read-only (calculate-purchase-points 
    (amount uint) 
    (is-local bool) 
    (is-organic bool) 
    (is-seasonal bool)
    (tier uint)
)
    (let
        (
            (base-points (/ amount u100)) ;; 1 point per $1 (assuming cents)
            (local-bonus (if is-local (* base-points LOCAL-PURCHASE-MULTIPLIER) u0))
            (organic-bonus (if is-organic (* base-points ORGANIC-PURCHASE-MULTIPLIER) u0))
            (seasonal-bonus (if is-seasonal (* base-points SEASONAL-PURCHASE-MULTIPLIER) u0))
            (tier-multiplier (get-tier-multiplier tier))
        )
        (* (+ base-points local-bonus organic-bonus seasonal-bonus) tier-multiplier)
    )
)

;; Get tier multiplier
(define-read-only (get-tier-multiplier (tier uint))
    (if (is-eq tier TIER-BRONZE) u1
        (if (is-eq tier TIER-SILVER) u12
            (if (is-eq tier TIER-GOLD) u15
                (if (is-eq tier TIER-PLATINUM) u18
                    (if (is-eq tier TIER-DIAMOND) u20 u10)
                )
            )
        )
    )
)

;; Check achievement eligibility
(define-read-only (check-achievement-eligibility (user-id uint) (achievement-id uint))
    (let
        (
            (user (unwrap! (map-get? users user-id) false))
            (achievement (unwrap! (map-get? achievements achievement-id) false))
            (user-achievement (map-get? user-achievements { user-id: user-id, achievement-id: achievement-id }))
        )
        (if (is-some user-achievement)
            false ;; Already unlocked
            (let
                (
                    (achievement-type (get achievement-type achievement))
                    (requirement (get requirement-value achievement))
                )
                (if (is-eq achievement-type ACHIEVEMENT-FIRST-PURCHASE)
                    (>= (get total-purchases user) u1)
                    (if (is-eq achievement-type ACHIEVEMENT-LOCAL-CHAMPION)
                        (>= (get local-purchases user) requirement)
                        (if (is-eq achievement-type ACHIEVEMENT-ECO-WARRIOR)
                            (>= (get organic-purchases user) requirement)
                            (if (is-eq achievement-type ACHIEVEMENT-SEASONAL-SUPPORTER)
                                (>= (get seasonal-purchases user) requirement)
                                false
                            )
                        )
                    )
                )
            )
        )
    )
)

;; Get total community statistics
(define-read-only (get-community-stats)
    {
        total-points-issued: (var-get total-points-issued),
        total-points-redeemed: (var-get total-points-redeemed),
        community-impact-score: (var-get community-impact-score),
        active-users: (var-get next-user-id),
        partner-businesses: (var-get next-business-id)
    }
)

;; Public functions

;; Register new user
(define-public (register-user
    (username (string-ascii 50))
    (email (string-ascii 100))
    (preferred-categories (list 5 (string-ascii 30)))
)
    (let
        (
            (user-id (var-get next-user-id))
        )
        (asserts! (> (len username) u0) ERR-INVALID-AMOUNT)
        (asserts! (is-none (map-get? user-wallets tx-sender)) ERR-ALREADY-EXISTS)
        
        (map-set users user-id
            {
                wallet: tx-sender,
                username: username,
                email: email,
                registration-date: stacks-block-height,
                total-points: u0,
                available-points: u0,
                tier: TIER-BRONZE,
                total-purchases: u0,
                local-purchases: u0,
                organic-purchases: u0,
                seasonal-purchases: u0,
                referrals-made: u0,
                community-score: u100,
                last-activity: stacks-block-height,
                preferred-categories: preferred-categories
            }
        )
        
        (map-set user-wallets tx-sender user-id)
        (var-set next-user-id (+ user-id u1))
        
        ;; Award welcome bonus
        (try! (award-points user-id u100 "Welcome bonus"))
        (ok user-id)
    )
)

;; Register partner business
(define-public (register-business
    (business-name (string-ascii 100))
    (category (string-ascii 50))
    (location (string-ascii 100))
    (description (string-ascii 300))
    (point-rate uint)
    (sustainability-rating uint)
)
    (let
        (
            (business-id (var-get next-business-id))
        )
        (asserts! (> (len business-name) u0) ERR-INVALID-AMOUNT)
        (asserts! (> point-rate u0) ERR-INVALID-AMOUNT)
        (asserts! (<= sustainability-rating u100) ERR-INVALID-AMOUNT)
        
        (map-set partner-businesses business-id
            {
                owner: tx-sender,
                business-name: business-name,
                category: category,
                location: location,
                description: description,
                point-rate: point-rate,
                sustainability-rating: sustainability-rating,
                registration-date: stacks-block-height,
                total-transactions: u0,
                active: true,
                special-offers: (list)
            }
        )
        
        (map-set business-owners tx-sender business-id)
        (var-set next-business-id (+ business-id u1))
        (ok business-id)
    )
)

;; Record purchase and award points
(define-public (record-purchase
    (user-id uint)
    (business-id uint)
    (amount uint)
    (is-local bool)
    (is-organic bool)
    (is-seasonal bool)
    (category (string-ascii 50))
)
    (let
        (
            (transaction-id (var-get next-transaction-id))
            (user (unwrap! (map-get? users user-id) ERR-USER-NOT-FOUND))
            (business (unwrap! (map-get? partner-businesses business-id) ERR-BUSINESS-NOT-FOUND))
            (points-earned (calculate-purchase-points amount is-local is-organic is-seasonal (get tier user)))
            (sustainability-bonus (if (and is-local is-organic) u20 u0))
        )
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        
        ;; Record transaction
        (map-set purchase-transactions transaction-id
            {
                user-id: user-id,
                business-id: business-id,
                amount: amount,
                points-earned: points-earned,
                purchase-date: stacks-block-height,
                is-local: is-local,
                is-organic: is-organic,
                is-seasonal: is-seasonal,
                category: category,
                sustainability-bonus: sustainability-bonus
            }
        )
        
        ;; Update user statistics
        (map-set users user-id
            (merge user {
                total-points: (+ (get total-points user) points-earned),
                available-points: (+ (get available-points user) points-earned),
                total-purchases: (+ (get total-purchases user) u1),
                local-purchases: (+ (get local-purchases user) (if is-local u1 u0)),
                organic-purchases: (+ (get organic-purchases user) (if is-organic u1 u0)),
                seasonal-purchases: (+ (get seasonal-purchases user) (if is-seasonal u1 u0)),
                last-activity: stacks-block-height
            })
        )
        
        ;; Update business statistics
        (map-set partner-businesses business-id
            (merge business {
                total-transactions: (+ (get total-transactions business) u1)
            })
        )
        
        ;; Update global statistics
        (var-set next-transaction-id (+ transaction-id u1))
        (var-set total-points-issued (+ (var-get total-points-issued) points-earned))
        (var-set community-impact-score (+ (var-get community-impact-score) sustainability-bonus))
        
        ;; Check for tier upgrade
        (try! (check-and-upgrade-tier user-id))
        
        ;; Check for achievements
        (unwrap-panic (check-and-unlock-achievements user-id))
        
        (ok points-earned)
    )
)

;; Private helper functions

;; Award points to user
(define-private (award-points (user-id uint) (points uint) (reason (string-ascii 100)))
    (let
        (
            (user (unwrap! (map-get? users user-id) ERR-USER-NOT-FOUND))
        )
        (map-set users user-id
            (merge user {
                total-points: (+ (get total-points user) points),
                available-points: (+ (get available-points user) points)
            })
        )
        (var-set total-points-issued (+ (var-get total-points-issued) points))
        (ok true)
    )
)

;; Check and upgrade user tier
(define-private (check-and-upgrade-tier (user-id uint))
    (let
        (
            (user (unwrap! (map-get? users user-id) ERR-USER-NOT-FOUND))
            (total-points (get total-points user))
            (current-tier (get tier user))
        )
        (let
            (
                (new-tier
                    (if (>= total-points u10000) TIER-DIAMOND
                        (if (>= total-points u5000) TIER-PLATINUM
                            (if (>= total-points u2000) TIER-GOLD
                                (if (>= total-points u500) TIER-SILVER
                                    TIER-BRONZE
                                )
                            )
                        )
                    )
                )
            )
            (if (> new-tier current-tier)
                (begin
                    (map-set users user-id (merge user { tier: new-tier }))
                    (try! (award-points user-id (* new-tier u50) "Tier upgrade bonus"))
                    (ok true)
                )
                (ok false)
            )
        )
    )
)

;; Check and unlock achievements
(define-private (check-and-unlock-achievements (user-id uint))
    (let
        (
            (achievement-ids (list u1 u2 u3 u4 u5))
        )
        (fold check-single-achievement achievement-ids user-id)
        (ok true)
    )
)

;; Check single achievement
(define-private (check-single-achievement (achievement-id uint) (user-id uint))
    (if (check-achievement-eligibility user-id achievement-id)
        (let
            (
                (achievement (unwrap! (map-get? achievements achievement-id) user-id))
            )
            (map-set user-achievements { user-id: user-id, achievement-id: achievement-id }
                {
                    unlocked-date: stacks-block-height,
                    claimed: false,
                    points-claimed: u0
                }
            )
            user-id
        )
        user-id
    )
)

;; Admin functions

;; Create achievement (admin only)
(define-public (create-achievement
    (name (string-ascii 100))
    (description (string-ascii 200))
    (achievement-type uint)
    (points-reward uint)
    (requirement-value uint)
    (icon (string-ascii 100))
)
    (let
        (
            (achievement-id (var-get next-achievement-id))
        )
        (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
        
        (map-set achievements achievement-id
            {
                name: name,
                description: description,
                achievement-type: achievement-type,
                points-reward: points-reward,
                requirement-value: requirement-value,
                icon: icon,
                is-active: true
            }
        )
        
        (var-set next-achievement-id (+ achievement-id u1))
        (ok achievement-id)
    )
)

;; title: community-rewards
;; version:
;; summary:
;; description:

;; traits
;;

;; token definitions
;;

;; constants
;;

;; data vars
;;

;; data maps
;;

;; public functions
;;

;; read only functions
;;

;; private functions
;;

