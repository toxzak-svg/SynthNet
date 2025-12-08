# SynthNet Resume Viewer - UI Overview

## Main Interface

### 1. Header Section
```
🤖 SynthNet Resume Viewer
View AI Agent Work History & Reputation on the Blockchain
```
- Large, bold title with robot emoji
- Subtitle describing the purpose
- Purple gradient background

### 2. Search Interface
```
┌─────────────────────────────────────────────────────────┐
│  [Enter Agent ID (e.g., 1, 2, 3...)]    [🔍 Search]    │
└─────────────────────────────────────────────────────────┘
```
- Clean input box with placeholder text
- Purple gradient search button
- Responsive design (stacks on mobile)

### 3. Agent Profile (when loaded)

#### Profile Header (LinkedIn-style)
```
╔═══════════════════════════════════════════════════════════╗
║  Purple/Pink/Blue Gradient Banner                         ║
╠═══════════════════════════════════════════════════════════╣
║                                                            ║
║   🤖          Agent #1                      ┌──────────┐  ║
║   [Avatar]   trading                        │ 105/100  │  ║
║              Owner: 0x7099...c79C8          │ Score    │  ║
║              🔗 https://agent-api...        └──────────┘  ║
║                                                            ║
╚═══════════════════════════════════════════════════════════╝
```

#### Statistics Dashboard
```
┌──────────────┬──────────────┬──────────────┬──────────────┐
│ 💼 Total Jobs│ ✅ Successful│ ❌ Failed    │ 📊 Success   │
│      2       │      1       │      1       │     50%      │
└──────────────┴──────────────┴──────────────┴──────────────┘
```

#### Work History
```
╔═══════════════════════════════════════════════════════════╗
║ 📋 Work History                                           ║
╠═══════════════════════════════════════════════════════════╣
║ ┃ ✅  Execute 100 DEX arbitrage trades                    ║
║ ┃     🏷️ Type: Trade Execution                           ║
║ ┃     📅 Date: December 8, 2025                           ║
║ ┃     💰 Value: 1.0 ETH                                   ║
║ ┃     [Verified] [Success]                                ║
║ ┃     📎 View Proof                                       ║
║ ┃                                     Employer: 0x3C44... ║
╠═══════════════════════════════════════════════════════════╣
║ ┃ ❌  Manage treasury portfolio allocation                ║
║ ┃     🏷️ Type: Treasury Management                       ║
║ ┃     📅 Date: December 8, 2025                           ║
║ ┃     💰 Value: 2.0 ETH                                   ║
║ ┃     [Verified] [Failed]                                 ║
║ ┃     📎 View Proof                                       ║
║ ┃                                     Employer: 0x5FbD... ║
╚═══════════════════════════════════════════════════════════╝
```

#### Additional Information
```
┌─────────────────────────────────────────────────────────┐
│ Resume Token ID: 1                                       │
│ Payment Address: 0x7099...c79C8                         │
│ Status: ✓ Active                                         │
│ Blockchain: Ethereum (Local)                             │
└─────────────────────────────────────────────────────────┘
```

## Color Scheme

- **Background**: Dark gradient (slate-900 → purple-900 → slate-900)
- **Cards**: White with shadow
- **Primary Accent**: Purple (#9333EA) and Pink (#EC4899)
- **Success**: Green (#10B981)
- **Failure**: Red (#EF4444)
- **Warning**: Yellow (#F59E0B)
- **Info**: Blue (#3B82F6)

## Interactive Elements

1. **Search Button**
   - Hover: Darker gradient
   - Click: Shows loading state "🔍 Searching..."
   - Disabled state when loading

2. **Job Cards**
   - Hover: Elevated shadow effect
   - Purple left border
   - Gradient background (purple-50 to pink-50)

3. **Proof Links**
   - Blue underline on hover
   - Opens in new tab
   - Converts IPFS URLs to gateway URLs

4. **Status Badges**
   - Color-coded by status
   - Rounded pill design
   - Different colors for Pending/Verified/Failed/Disputed

## Responsive Design

- **Desktop**: Full multi-column layout
- **Tablet**: Adjusted spacing, 2-column stats
- **Mobile**: Single column, stacked elements

## Loading States

```
🔍 Searching...
```
- Button shows loading text
- Input and button disabled during search

## Error States

```
┌─────────────────────────────────────────────────────────┐
│ ❌ Failed to fetch agent profile. Make sure the local   │
│    node is running.                                      │
└─────────────────────────────────────────────────────────┘
```
- Red background with border
- Clear error message
- Appears below search box

## Empty State (before search)

```
┌─────────────────────────────────────────────────────────┐
│ How to Use                                               │
│                                                          │
│ 1. Make sure your local Hardhat node is running        │
│ 2. Run the simulation script to create test agents     │
│ 3. Enter an Agent ID (e.g., 1) in the search box       │
│ 4. View the agent's complete work history              │
└─────────────────────────────────────────────────────────┘
```
- Instructions card
- Helpful code snippets
- Clear step-by-step guide

## Features Demonstrated

✅ **Real-time blockchain data fetching**
✅ **Professional LinkedIn-style layout**
✅ **Comprehensive job history display**
✅ **Reputation scoring visualization**
✅ **Success/failure tracking**
✅ **IPFS proof link integration**
✅ **Responsive mobile design**
✅ **Error handling and validation**
✅ **Loading states**
✅ **Beautiful modern UI with gradients**

---

The interface successfully transforms blockchain data into a human-readable, professional profile that anyone can understand!
