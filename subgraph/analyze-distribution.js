#!/usr/bin/env node

/**
 * Holons Distribution Analysis Tool
 * Analyzes distribution flows at scale using GraphQL queries
 */

const https = require('https');
const http = require('http');

class HolonsAnalyzer {
  constructor(subgraphUrl) {
    this.subgraphUrl = subgraphUrl;
  }

  async queryGraphQL(query, variables = {}) {
    return new Promise((resolve, reject) => {
      const url = new URL(this.subgraphUrl);
      const isHttps = url.protocol === 'https:';
      const client = isHttps ? https : http;
      
      const postData = JSON.stringify({
        query,
        variables
      });

      const options = {
        hostname: url.hostname,
        port: url.port,
        path: url.pathname,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(postData)
        }
      };

      const req = client.request(options, (res) => {
        let data = '';
        res.on('data', (chunk) => data += chunk);
        res.on('end', () => {
          try {
            resolve(JSON.parse(data));
          } catch (e) {
            reject(e);
          }
        });
      });

      req.on('error', reject);
      req.write(postData);
      req.end();
    });
  }

  async analyzeDistribution(txHash) {
    console.log(`🔍 Analyzing distribution: ${txHash}\n`);

    // Get all events from this transaction
    const events = await this.getTransactionEvents(txHash);
    
    // Analyze the flow
    const analysis = this.analyzeFlow(events);
    
    // Generate report
    this.generateReport(analysis);
    
    return analysis;
  }

  async getTransactionEvents(txHash) {
    const query = `
      query GetTransactionEvents($txHash: Bytes!) {
        fundsForwardeds(where: { txHash: $txHash }) {
          id
          splitterAddress
          toAddress
          tokenAddress
          amount
          timestamp
          blockNumber
        }
        memberRewardeds(where: { txHash: $txHash }) {
          id
          contractAddress
          recipient
          amount
          isContract
          rewardType
          timestamp
          blockNumber
        }
        rewardDistributeds(where: { txHash: $txHash }) {
          id
          contractAddress
          totalAmount
          totalMembers
          rewardType
          timestamp
          blockNumber
        }
      }
    `;

    const result = await this.queryGraphQL(query, { txHash });
    return result.data;
  }

  analyzeFlow(events) {
    const analysis = {
      transaction: {
        fundsForwarded: events.fundsForwardeds || [],
        memberRewarded: events.memberRewardeds || [],
        rewardDistributed: events.rewardDistributeds || []
      },
      flow: {
        totalETH: 0,
        totalRecipients: 0,
        crossContractRewards: 0,
        splitterActivity: new Map(),
        childContractActivity: new Map()
      }
    };

    // Analyze funds forwarded
    events.fundsForwardeds?.forEach(event => {
      const amount = parseFloat(event.amount) / 1e18; // Convert wei to ETH
      analysis.flow.totalETH += amount;
      
      // Track splitter activity
      if (!analysis.flow.splitterActivity.has(event.splitterAddress)) {
        analysis.flow.splitterActivity.set(event.splitterAddress, {
          forwards: 0,
          totalAmount: 0
        });
      }
      const splitter = analysis.flow.splitterActivity.get(event.splitterAddress);
      splitter.forwards++;
      splitter.totalAmount += amount;
    });

    // Analyze member rewards
    events.memberRewardeds?.forEach(event => {
      const amount = parseFloat(event.amount) / 1e18;
      analysis.flow.totalRecipients++;
      
      if (event.isContract) {
        analysis.flow.crossContractRewards++;
      }
      
      // Track child contract activity
      if (!analysis.flow.childContractActivity.has(event.contractAddress)) {
        analysis.flow.childContractActivity.set(event.contractAddress, {
          rewards: 0,
          totalAmount: 0
        });
      }
      const child = analysis.flow.childContractActivity.get(event.contractAddress);
      child.rewards++;
      child.totalAmount += amount;
    });

    return analysis;
  }

  generateReport(analysis) {
    console.log('📊 DISTRIBUTION ANALYSIS REPORT');
    console.log('================================\n');

    // Transaction summary
    console.log('💰 TRANSACTION SUMMARY:');
    console.log(`   Total ETH Distributed: ${analysis.flow.totalETH.toFixed(4)} ETH`);
    console.log(`   Total Recipients: ${analysis.flow.totalRecipients}`);
    console.log(`   Cross-Contract Rewards: ${analysis.flow.crossContractRewards}\n`);

    // Splitter activity
    console.log('🔄 SPLITTER ACTIVITY:');
    analysis.flow.splitterActivity.forEach((activity, address) => {
      console.log(`   ${address}:`);
      console.log(`     Forwards: ${activity.forwards}`);
      console.log(`     Total Amount: ${activity.totalAmount.toFixed(4)} ETH`);
    });
    console.log('');

    // Child contract activity
    console.log('🎁 CHILD CONTRACT ACTIVITY:');
    analysis.flow.childContractActivity.forEach((activity, address) => {
      console.log(`   ${address}:`);
      console.log(`     Rewards: ${activity.rewards}`);
      console.log(`     Total Amount: ${activity.totalAmount.toFixed(4)} ETH`);
    });
    console.log('');

    // Event breakdown
    console.log('📋 EVENT BREAKDOWN:');
    console.log(`   FundsForwarded: ${analysis.transaction.fundsForwarded.length} events`);
    console.log(`   MemberRewarded: ${analysis.transaction.memberRewarded.length} events`);
    console.log(`   RewardDistributed: ${analysis.transaction.rewardDistributed.length} events`);
  }

  async analyzeTimeRange(fromTimestamp, toTimestamp) {
    console.log(`📅 Analyzing time range: ${fromTimestamp} to ${toTimestamp}\n`);

    const query = `
      query GetTimeRangeEvents($fromTimestamp: BigInt!, $toTimestamp: BigInt!) {
        fundsForwardeds(
          where: { 
            timestamp_gte: $fromTimestamp,
            timestamp_lte: $toTimestamp 
          }
          orderBy: timestamp
          orderDirection: desc
        ) {
          id
          splitterAddress
          toAddress
          amount
          timestamp
          txHash
        }
        memberRewardeds(
          where: { 
            timestamp_gte: $fromTimestamp,
            timestamp_lte: $toTimestamp 
          }
          orderBy: timestamp
          orderDirection: desc
        ) {
          id
          contractAddress
          recipient
          amount
          isContract
          rewardType
          timestamp
          txHash
        }
        rewardDistributeds(
          where: { 
            timestamp_gte: $fromTimestamp,
            timestamp_lte: $toTimestamp 
          }
          orderBy: timestamp
          orderDirection: desc
        ) {
          id
          contractAddress
          totalAmount
          totalMembers
          rewardType
          timestamp
          txHash
        }
      }
    `;

    const result = await this.queryGraphQL(query, { fromTimestamp, toTimestamp });
    return result.data;
  }
}

// Usage example
async function main() {
  const analyzer = new HolonsAnalyzer('http://localhost:8000/subgraphs/name/holons-local-v1');
  
  // Analyze specific transaction
  await analyzer.analyzeDistribution('0xe5d0df8ae3594896e06def3cca7dafb6ab3ce406a331677af9f9382b3160d54b');
  
  // Analyze time range (last 24 hours)
  const now = Math.floor(Date.now() / 1000);
  const dayAgo = now - (24 * 60 * 60);
  const timeRangeData = await analyzer.analyzeTimeRange(dayAgo.toString(), now.toString());
  
  console.log('\n📈 TIME RANGE ANALYSIS:');
  console.log(`   FundsForwarded: ${timeRangeData.fundsForwardeds.length} events`);
  console.log(`   MemberRewarded: ${timeRangeData.memberRewardeds.length} events`);
  console.log(`   RewardDistributed: ${timeRangeData.rewardDistributeds.length} events`);
}

if (require.main === module) {
  main().catch(console.error);
}

module.exports = HolonsAnalyzer;
