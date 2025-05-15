
;; Define the contract's data storage
(define-data-var token-name (string-ascii 32) "USDStable")
(define-data-var token-symbol (string-ascii 10) "USDS")
(define-data-var token-decimals uint u6)
(define-data-var token-supply uint u0)

;; Define governance variables
(define-data-var contract-owner principal tx-sender)
(define-data-var is-paused bool false)

;; Define token metadata URI
(define-data-var token-uri (optional (string-utf8 256)) none)

;; Map to store user balances
(define-map balances principal uint)

;; Map to store allowances for delegated transfers
(define-map allowances {owner: principal, spender: principal} uint)

;; Map for blacklisted addresses
(define-map blacklisted principal bool)

;; Define error codes
(define-constant ERR-NOT-AUTHORIZED u1)
(define-constant ERR-NOT-FOUND u2)
(define-constant ERR-CONTRACT-PAUSED u3)
(define-constant ERR-INSUFFICIENT-BALANCE u4)
(define-constant ERR-INSUFFICIENT-ALLOWANCE u5)
(define-constant ERR-ADDRESS-BLACKLISTED u6)
(define-constant ERR-INVALID-AMOUNT u7)

;; Authorization check
(define-private (is-authorized)
  (is-eq tx-sender (var-get contract-owner)))

;; Check if address is blacklisted
(define-private (is-blacklisted (address principal))
  (default-to false (map-get? blacklisted address)))

;; Check if contract paused
(define-private (is-contract-paused)
  (var-get is-paused))

;; Get user balance
(define-read-only (get-balance (user principal))
  (default-to u0 (map-get? balances user)))

;; Get total supply
(define-read-only (get-total-supply)
  (var-get token-supply))

;; Get token name
(define-read-only (get-name)
  (var-get token-name))
;; Get token symbol
(define-read-only (get-symbol)
  (var-get token-symbol))

;; Get token decimals
(define-read-only (get-decimals)
  (var-get token-decimals))

;; Get token URI
(define-read-only (get-token-uri)
  (var-get token-uri))

;; Get allowance
(define-read-only (get-allowance (owner principal) (spender principal))
  (default-to u0 (map-get? allowances {owner: owner, spender: spender})))
;; Transfer tokens
(define-public (transfer (amount uint) (recipient principal))
  (let ((sender-balance (get-balance tx-sender))
        (recipient-balance (get-balance recipient)))
    (asserts! (not (is-contract-paused)) (err ERR-CONTRACT-PAUSED))
    (asserts! (not (is-blacklisted tx-sender)) (err ERR-ADDRESS-BLACKLISTED))
    (asserts! (not (is-blacklisted recipient)) (err ERR-ADDRESS-BLACKLISTED))
    (asserts! (>= sender-balance amount) (err ERR-INSUFFICIENT-BALANCE))
    
    (map-set balances tx-sender (- sender-balance amount))
    (map-set balances recipient (+ recipient-balance amount))
    
    (ok true)))

;; Transfer tokens from one account to another (with allowance)
(define-public (transfer-from (amount uint) (sender principal) (recipient principal))
  (let ((sender-balance (get-balance sender))
        (recipient-balance (get-balance recipient))
        (current-allowance (get-allowance sender tx-sender)))
    (asserts! (not (is-contract-paused)) (err ERR-CONTRACT-PAUSED))
    (asserts! (not (is-blacklisted tx-sender)) (err ERR-ADDRESS-BLACKLISTED))
    (asserts! (not (is-blacklisted sender)) (err ERR-ADDRESS-BLACKLISTED))
    (asserts! (not (is-blacklisted recipient)) (err ERR-ADDRESS-BLACKLISTED))
    (asserts! (>= sender-balance amount) (err ERR-INSUFFICIENT-BALANCE))
    (asserts! (>= current-allowance amount) (err ERR-INSUFFICIENT-ALLOWANCE))
    
    (map-set balances sender (- sender-balance amount))
    (map-set balances recipient (+ recipient-balance amount))
    (map-set allowances {owner: sender, spender: tx-sender} (- current-allowance amount))
    
    (ok true)))
;; Approve spending
(define-public (approve (amount uint) (spender principal))
  (begin
    (asserts! (not (is-contract-paused)) (err ERR-CONTRACT-PAUSED))
    (asserts! (not (is-blacklisted tx-sender)) (err ERR-ADDRESS-BLACKLISTED))
    (asserts! (not (is-blacklisted spender)) (err ERR-ADDRESS-BLACKLISTED))
    
    (map-set allowances {owner: tx-sender, spender: spender} amount)
    (ok true)))

;; Mint new tokens (only contract owner)
(define-public (mint (amount uint) (recipient principal))
  (let ((current-balance (get-balance recipient))
        (current-supply (var-get token-supply)))
    (asserts! (is-authorized) (err ERR-NOT-AUTHORIZED))
    (asserts! (not (is-contract-paused)) (err ERR-CONTRACT-PAUSED))
    (asserts! (not (is-blacklisted recipient)) (err ERR-ADDRESS-BLACKLISTED))
    (asserts! (> amount u0) (err ERR-INVALID-AMOUNT))
    
    (var-set token-supply (+ current-supply amount))
    (map-set balances recipient (+ current-balance amount))
    
    (ok true)))

;; Burn tokens
(define-public (burn (amount uint))
  (let ((current-balance (get-balance tx-sender))
        (current-supply (var-get token-supply)))
    (asserts! (not (is-contract-paused)) (err ERR-CONTRACT-PAUSED))
    (asserts! (not (is-blacklisted tx-sender)) (err ERR-ADDRESS-BLACKLISTED))
    (asserts! (>= current-balance amount) (err ERR-INSUFFICIENT-BALANCE))
    (asserts! (> amount u0) (err ERR-INVALID-AMOUNT))
    
    (var-set token-supply (- current-supply amount))
    (map-set balances tx-sender (- current-balance amount))
    
    (ok true)))
;; Administrative functions (only contract owner)

;; Set new contract owner
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-authorized) (err ERR-NOT-AUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)))

;; Pause the contract
(define-public (pause-contract)
  (begin
    (asserts! (is-authorized) (err ERR-NOT-AUTHORIZED))
    (var-set is-paused true)
    (ok true)))

;; Unpause the contract
(define-public (unpause-contract)
  (begin
    (asserts! (is-authorized) (err ERR-NOT-AUTHORIZED))
    (var-set is-paused false)
    (ok true)))

;; Blacklist an address
(define-public (blacklist-address (address principal))
  (begin
    (asserts! (is-authorized) (err ERR-NOT-AUTHORIZED))
    (map-set blacklisted address true)
    (ok true)))

;; Remove address from blacklist
(define-public (remove-from-blacklist (address principal))
  (begin
    (asserts! (is-authorized) (err ERR-NOT-AUTHORIZED))
    (map-set blacklisted address false)
    (ok true)))

;; Set token metadata URI
(define-public (set-token-uri (new-uri (string-utf8 256)))
  (begin
    (asserts! (is-authorized) (err ERR-NOT-AUTHORIZED))
    (var-set token-uri (some new-uri))
    (ok true)))

;; SIP-010 compliance functions

;; Transfer with memo
(define-public (transfer-memo (amount uint) (recipient principal) (memo (buff 34)))
  (begin
    (try! (transfer amount recipient))
    (print memo)
    (ok true)))

;; SIP-010 get token balance
(define-read-only (get-balance-of (owner principal))
  (ok (get-balance owner)))

;; SIP-010 get total supply
(define-read-only (get-total-supply-of)
  (ok (var-get token-supply)))