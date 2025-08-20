# 🏆 On-Chain Game Tournament Prize Pool

A comprehensive smart contract built with Clarity for managing game tournaments and their prize distributions on the Stacks blockchain. Perfect for learning prize pool locking mechanisms and automated payouts! 🎮

## ✨ Features

- 🎯 **Tournament Creation**: Create tournaments with custom entry fees and names
- 👥 **Player Registration**: Join tournaments by paying the entry fee
- 💰 **Prize Pool Management**: Automatic accumulation of entry fees into prize pools
- 🏅 **Winner Selection**: Tournament organizers can select winners and distribute prizes
- 💎 **Automated Payouts**: Winners can claim their prizes directly from the contract
- 🔒 **Secure Fund Locking**: Entry fees are locked in the contract until tournament ends
- 📊 **Prize Distribution**: Customizable percentage-based prize distribution
- ⛔ **Tournament Cancellation**: Organizers can cancel tournaments and refund participants
- 🕐 **Unclaimed Fund Recovery**: Organizers can recover unclaimed prizes after timeout

## 🚀 Quick Start

### Prerequisites
- Clarinet installed
- Stacks wallet for testing

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd On-Chain-Game-Tournament-Prize-Pool
```

2. Install dependencies:
```bash
clarinet check
```

## 📖 Usage Guide

### 1. Creating a Tournament 🎪

```clarity
(contract-call? .on-chain-game-tourrnament-prize-pool create-tournament "Summer Championship" u1000000)
```

**Parameters:**
- `name`: Tournament name (max 50 characters)
- `entry-fee`: Entry fee in micro-STX (1 STX = 1,000,000 micro-STX)

**Returns:** Tournament ID

### 2. Joining a Tournament 🎯

```clarity
(contract-call? .on-chain-game-tourrnament-prize-pool join-tournament u1)
```

**Parameters:**
- `tournament-id`: The ID of the tournament to join

**Requirements:**
- Must pay the exact entry fee
- Tournament must be in "open" status
- Cannot join the same tournament twice

### 3. Ending a Tournament 🏁

```clarity
(contract-call? .on-chain-game-tourrnament-prize-pool end-tournament 
  u1 
  (list 'SP1ABC... 'SP2DEF...)
  (list u50 u30 u20))
```

**Parameters:**
- `tournament-id`: Tournament to end
- `winners`: List of winner principals (max 10)
- `prize-percentages`: Prize distribution percentages (must sum to 100)

**Requirements:**
- Only tournament organizer can end tournaments
- Percentages must sum to exactly 100
- Number of winners must match number of percentages

### 4. Claiming Prizes 💰

```clarity
(contract-call? .on-chain-game-tourrnament-prize-pool claim-prize u1)
```

**Parameters:**
- `tournament-id`: Tournament ID to claim prize from

**Requirements:**
- Must be a winner of the tournament
- Prize must not have been claimed already
- Tournament must be ended

### 5. Cancelling a Tournament ❌

```clarity
(contract-call? .on-chain-game-tourrnament-prize-pool cancel-tournament u1)
```

**Parameters:**
- `tournament-id`: Tournament to cancel

**Requirements:**
- Only tournament organizer can cancel
- Tournament must still be "open"
- All participants are automatically refunded

## 🔍 Query Functions

### Get Tournament Info
```clarity
(contract-call? .on-chain-game-tourrnament-prize-pool get-tournament u1)
```

### Check Participant Status
```clarity
(contract-call? .on-chain-game-tourrnament-prize-pool get-participant-info 'SP1ABC... u1)
```

### View Tournament Participants
```clarity
(contract-call? .on-chain-game-tourrnament-prize-pool get-tournament-participants u1)
```

### View Winners
```clarity
(contract-call? .on-chain-game-tourrnament-prize-pool get-tournament-winners u1)
```

### Check Prize Pool
```clarity
(contract-call? .on-chain-game-tourrnament-prize-pool get-prize-pool u1)
```

## 💼 Contract Economics

- **Organizer Fee**: 5% of total prize pool
- **Prize Distribution**: 95% of prize pool distributed to winners
- **Entry Fee Locking**: All entry fees immediately locked in contract
- **Refund Policy**: Full refunds available if tournament is cancelled

## 🏗️ Architecture

The contract uses two main data structures:

1. **Tournaments Map**: Stores tournament metadata including organizer, participants, prize pool, and status
2. **Participant-Tournaments Map**: Tracks individual participant data including join time, prize amounts, and claim status

## 🛡️ Security Features

- ✅ Authorization checks for organizer-only functions
- ✅ Duplicate participation prevention
- ✅ Prize double-claim prevention
- ✅ Automatic fund locking and release
- ✅ Timeout-based unclaimed fund recovery

## 🔧 Error Codes

| Code | Description |
|------|-------------|
| u401 | Unauthorized access |
| u404 | Tournament not found |
| u409 | Already exists (duplicate join) |
| u400 | Invalid amount |
| u403 | Tournament active (when it should be inactive) |
| u410 | Tournament ended |
| u411 | Already joined |
| u412 | Not a participant |
| u413 | Insufficient balance |
| u414 | Prize already claimed |
| u415 | No prize available |

## 🧪 Testing

Run the test suite:
```bash
clarinet test
```

Example test scenarios:
- Tournament creation and joining
- Prize distribution calculations
- Winner selection and payout
- Tournament cancellation and refunds
- Edge cases and error handling

## 📝 License

This project is open source and available under the MIT License.

## 🤝 Contributing

Contributions are welcome! Feel free to submit issues and enhancement requests.

---

**Happy Gaming! 🎮🚀**
