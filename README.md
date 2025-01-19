# Stark-notes Project Explanation

## Overview

This document outlines a system being developed for the StarkNet Hackathon. The system involves reviewers assessing "logos," which are statements answerable by "yes" or "no." Key components include reviewers, the agora pool, logos, and bounties.

## Players and Concepts

### Reviewers

- **Role**: Vote on the factual accuracy of logos.
- **Participation**:
  - Open to anyone.
  - Reviewers vote on the validity of proposed logos.
- **Anonymity**: Ideally anonymous, though enforcing anonymity is challenging.
- **Staking & Reputation**:
  - Reviewers must stake some stark or reputation  to participate.
  - Reputation increases if votes align with the eventual "settled" consensus.
  - This is simpler than a full-blown decentralized oracle network but still encourages honest behavior.

### Agora Pool

- **Function**: Platform where reviewers vote on logos.
- **Features**:
  - May include off-chain discussion (like a debate system).
- **Voting Mechanisms**:
  - A minimum participation threshold (e.g., at least three votes).
  - Weighted votes based on reviewer reputation.
  - "Truth" outcome can shift over time if new majority forms.

### Logos

- **Definition**: Statements answerable by "yes" or "no."
- **Proposal**:
  - Anyone can propose a logo.
  - Must be clearly phrased to prevent confusion.
- **Validity Assessment**:
  - Votes accumulate.
  - Once threshold reached, a grace period begins. If unchallenged, outcome can be "settled."
  - However, logos remain open and may re-trigger settlement if the majority flips later.

### Bounty

- **Determination**:
  - Funded by individuals who care about the logo's outcome.
  - May be topped up at any time (e.g., via deposit_bounty).
- **Allocation**:
  - Distributed to the majority side once a logo is finalized after its grace period.
  - Could be reallocated if a new majority emerges and triggers a new settlement.

## General System Questions

1. **Outcome of Logos**:
   - Not permanently closed. If a new majority arises, a new grace period starts, and the bounty distribution can repeat.
2. **System Implementation**:
   - Hybrid on-chain/off-chain.
   - On-chain logic handles proposals, votes, grace timelines, and bounty distribution.
   - Off-chain chat rooms for discussions and debates.
3. **Dispute Resolution**:
   - Arbitration modules for contests or malicious actions.
   - A review system that slashes stake or reduces reputation if foul play is proven.
4. **Preventing Bias**:
   - A diverse set of voters, each with some stake or reputation at risk.
   - Future expansions to incorporate advanced identity or reputation modules.
5. **User Incentives**:
   - Earn bounty for correct (majority) votes.
   - Build reputation with each validated settlement.

## Potential Future Additions
(to be considered for implementation in the future)
### Reviewer Identity

- **Enhanced Profiles via Third-Party Identity for Synergy with Anonymity Constraints**:
  - Adding properties to reviewers' identities.
  - Incorporating third-party identity providers to build reputation.

### Federated Arbitration Modules

- **Focus on Special Cases or Suspected Coordination to Enforce Fairness and Reduce Malicious Behavior**:
  - Arbitrators compete to establish trusted reputations.
  - Aim to fairly determine outcomes in edge cases and enforce penalties for malicious actions.


