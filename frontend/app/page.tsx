'use client';

import { useState } from 'react';
import { BlockchainService, AgentProfile } from '../lib/blockchain';
import { JOB_TYPES, JOB_STATUS } from '../lib/contracts';
import { ethers } from 'ethers';

export default function Home() {
  const [agentId, setAgentId] = useState('');
  const [profile, setProfile] = useState<AgentProfile | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleSearch = async () => {
    if (!agentId || agentId.trim() === '') {
      setError('Please enter an Agent ID');
      return;
    }

    setLoading(true);
    setError('');
    setProfile(null);

    try {
      const blockchain = new BlockchainService();
      const agentProfile = await blockchain.getAgentProfile(agentId);
      setProfile(agentProfile);
    } catch (err: any) {
      setError(err.message || 'Failed to fetch agent profile. Make sure the local node is running.');
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const calculateScore = (reputation: bigint): number => {
    // Convert reputation to a 0-100 score
    // Base reputation is 100, max reasonable reputation is ~200
    const score = Math.min(100, Math.max(0, Number(reputation) - 50));
    return score;
  };

  const formatDate = (timestamp: bigint): string => {
    return new Date(Number(timestamp) * 1000).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    });
  };

  const formatAddress = (address: string): string => {
    return `${address.slice(0, 6)}...${address.slice(-4)}`;
  };

  const formatEther = (value: bigint): string => {
    return ethers.formatEther(value);
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-purple-900 to-slate-900 py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-7xl mx-auto">
        {/* Header */}
        <div className="text-center mb-12">
          <h1 className="text-5xl font-bold text-white mb-4">
            🤖 SynthNet Resume Viewer
          </h1>
          <p className="text-xl text-purple-200">
            View AI Agent Work History & Reputation on the Blockchain
          </p>
        </div>

        {/* Search Box */}
        <div className="bg-white/10 backdrop-blur-lg rounded-2xl shadow-2xl p-8 mb-8 border border-purple-400/30">
          <div className="flex flex-col sm:flex-row gap-4">
            <input
              type="text"
              value={agentId}
              onChange={(e) => setAgentId(e.target.value)}
              placeholder="Enter Agent ID (e.g., 1, 2, 3...)"
              className="flex-1 px-6 py-4 bg-white/90 border-2 border-purple-300 rounded-xl text-gray-900 placeholder-gray-500 focus:outline-none focus:border-purple-500 focus:ring-2 focus:ring-purple-500/50 text-lg"
              onKeyPress={(e) => e.key === 'Enter' && handleSearch()}
            />
            <button
              onClick={handleSearch}
              disabled={loading}
              className="px-8 py-4 bg-gradient-to-r from-purple-600 to-pink-600 text-white font-semibold rounded-xl hover:from-purple-700 hover:to-pink-700 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-200 shadow-lg hover:shadow-xl text-lg"
            >
              {loading ? '🔍 Searching...' : '🔍 Search'}
            </button>
          </div>

          {error && (
            <div className="mt-4 p-4 bg-red-500/20 border border-red-400 rounded-xl text-red-200">
              ❌ {error}
            </div>
          )}
        </div>

        {/* Profile Display */}
        {profile && (
          <div className="space-y-6">
            {/* Header Card - LinkedIn Style */}
            <div className="bg-white rounded-2xl shadow-2xl overflow-hidden">
              {/* Banner */}
              <div className="h-32 bg-gradient-to-r from-purple-600 via-pink-600 to-blue-600"></div>
              
              {/* Profile Info */}
              <div className="px-8 pb-8">
                <div className="flex flex-col sm:flex-row gap-6 -mt-16">
                  {/* Avatar */}
                  <div className="flex-shrink-0">
                    <div className="w-32 h-32 bg-gradient-to-br from-purple-500 to-pink-500 rounded-2xl border-4 border-white shadow-xl flex items-center justify-center text-5xl">
                      🤖
                    </div>
                  </div>

                  {/* Info */}
                  <div className="flex-1 pt-4">
                    <div className="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4">
                      <div>
                        <h2 className="text-3xl font-bold text-gray-900 mb-2">
                          Agent #{profile.agentId}
                        </h2>
                        <p className="text-lg text-purple-600 font-semibold mb-2">
                          {profile.agentData.category || 'AI Agent'}
                        </p>
                        <p className="text-sm text-gray-600 mb-2">
                          Owner: <span className="font-mono">{formatAddress(profile.owner)}</span>
                        </p>
                        {profile.agentData.serviceUrl && (
                          <a 
                            href={profile.agentData.serviceUrl}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="text-sm text-blue-600 hover:underline flex items-center gap-1"
                          >
                            🔗 {profile.agentData.serviceUrl}
                          </a>
                        )}
                      </div>

                      {/* Score Badge */}
                      <div className="flex-shrink-0">
                        <div className="bg-gradient-to-br from-green-400 to-emerald-600 text-white rounded-2xl px-6 py-4 text-center shadow-lg">
                          <div className="text-4xl font-bold">
                            {calculateScore(profile.stats.reputation)}/100
                          </div>
                          <div className="text-sm font-semibold mt-1">
                            Reputation Score
                          </div>
                          <div className="text-xs mt-1 opacity-90">
                            ({profile.stats.reputation.toString()} points)
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            {/* Stats Cards */}
            <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
              <div className="bg-white rounded-xl shadow-lg p-6">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm text-gray-600 font-semibold">Total Jobs</p>
                    <p className="text-3xl font-bold text-gray-900 mt-2">
                      {profile.stats.totalJobs.toString()}
                    </p>
                  </div>
                  <div className="text-4xl">💼</div>
                </div>
              </div>

              <div className="bg-white rounded-xl shadow-lg p-6">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm text-gray-600 font-semibold">Successful</p>
                    <p className="text-3xl font-bold text-green-600 mt-2">
                      {profile.stats.successfulJobs.toString()}
                    </p>
                  </div>
                  <div className="text-4xl">✅</div>
                </div>
              </div>

              <div className="bg-white rounded-xl shadow-lg p-6">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm text-gray-600 font-semibold">Failed</p>
                    <p className="text-3xl font-bold text-red-600 mt-2">
                      {profile.stats.failedJobs.toString()}
                    </p>
                  </div>
                  <div className="text-4xl">❌</div>
                </div>
              </div>

              <div className="bg-white rounded-xl shadow-lg p-6">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm text-gray-600 font-semibold">Success Rate</p>
                    <p className="text-3xl font-bold text-blue-600 mt-2">
                      {profile.stats.totalJobs > BigInt(0)
                        ? `${Math.round((Number(profile.stats.successfulJobs) / Number(profile.stats.totalJobs)) * 100)}%`
                        : 'N/A'
                      }
                    </p>
                  </div>
                  <div className="text-4xl">📊</div>
                </div>
              </div>
            </div>

            {/* Work History */}
            <div className="bg-white rounded-2xl shadow-2xl p-8">
              <h3 className="text-2xl font-bold text-gray-900 mb-6 flex items-center gap-2">
                📋 Work History
              </h3>

              {profile.jobs.length === 0 ? (
                <div className="text-center py-12 text-gray-500">
                  <div className="text-6xl mb-4">📭</div>
                  <p className="text-lg">No jobs completed yet</p>
                </div>
              ) : (
                <div className="space-y-4">
                  {profile.jobs.map((job, index) => (
                    <div 
                      key={job.jobId.toString()}
                      className="border-l-4 border-purple-500 bg-gradient-to-r from-purple-50 to-pink-50 rounded-r-xl p-6 hover:shadow-lg transition-shadow"
                    >
                      <div className="flex flex-col lg:flex-row lg:items-start lg:justify-between gap-4">
                        <div className="flex-1">
                          <div className="flex items-start gap-3 mb-3">
                            <div className="text-2xl">
                              {job.success ? '✅' : job.status === 2 ? '❌' : job.status === 0 ? '⏳' : '⚠️'}
                            </div>
                            <div className="flex-1">
                              <h4 className="text-lg font-bold text-gray-900 mb-1">
                                {job.description}
                              </h4>
                              <div className="flex flex-wrap gap-3 text-sm text-gray-600">
                                <span className="flex items-center gap-1">
                                  🏷️ <strong>Type:</strong> {JOB_TYPES[job.jobType]}
                                </span>
                                <span className="flex items-center gap-1">
                                  📅 <strong>Date:</strong> {formatDate(job.timestamp)}
                                </span>
                                <span className="flex items-center gap-1">
                                  💰 <strong>Value:</strong> {formatEther(job.value)} ETH
                                </span>
                              </div>
                            </div>
                          </div>

                          <div className="flex flex-wrap gap-2 mt-3">
                            <span className={`px-3 py-1 rounded-full text-xs font-semibold ${
                              job.status === 1 ? 'bg-green-100 text-green-800' :
                              job.status === 2 ? 'bg-red-100 text-red-800' :
                              job.status === 3 ? 'bg-yellow-100 text-yellow-800' :
                              'bg-gray-100 text-gray-800'
                            }`}>
                              {JOB_STATUS[job.status]}
                            </span>
                            
                            {job.success && (
                              <span className="px-3 py-1 rounded-full text-xs font-semibold bg-blue-100 text-blue-800">
                                Success
                              </span>
                            )}
                          </div>

                          {job.proofUri && (
                            <div className="mt-3">
                              <a 
                                href={job.proofUri.startsWith('ipfs://') 
                                  ? `https://ipfs.io/ipfs/${job.proofUri.replace('ipfs://', '')}`
                                  : job.proofUri
                                }
                                target="_blank"
                                rel="noopener noreferrer"
                                className="text-sm text-purple-600 hover:underline flex items-center gap-1"
                              >
                                📎 View Proof
                              </a>
                            </div>
                          )}
                        </div>

                        <div className="text-right text-sm text-gray-600 flex-shrink-0">
                          <p className="font-semibold">Employer</p>
                          <p className="font-mono text-xs">{formatAddress(job.employer)}</p>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* Additional Info */}
            <div className="bg-white/10 backdrop-blur-lg rounded-xl p-6 border border-purple-400/30">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm text-purple-100">
                <div>
                  <strong>Resume Token ID:</strong> {profile.resumeId.toString()}
                </div>
                <div>
                  <strong>Payment Address:</strong>{' '}
                  <span className="font-mono">{formatAddress(profile.agentData.paymentAddress)}</span>
                </div>
                <div>
                  <strong>Status:</strong> <span className="text-green-400">✓ Active</span>
                </div>
                <div>
                  <strong>Blockchain:</strong> Ethereum (Local)
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Instructions */}
        {!profile && !loading && (
          <div className="bg-white/10 backdrop-blur-lg rounded-2xl p-8 border border-purple-400/30">
            <h3 className="text-2xl font-bold text-white mb-4">
              How to Use
            </h3>
            <ol className="list-decimal list-inside space-y-3 text-purple-100">
              <li>Make sure your local Hardhat node is running (<code className="bg-black/30 px-2 py-1 rounded">npx hardhat node</code>)</li>
              <li>Run the simulation script to create test agents (<code className="bg-black/30 px-2 py-1 rounded">npx hardhat run scripts/simulate-lifecycle.js --network localhost</code>)</li>
              <li>Enter an Agent ID (e.g., <strong>1</strong>) in the search box above</li>
              <li>View the agent's complete work history and reputation on the blockchain</li>
            </ol>
          </div>
        )}
      </div>
    </div>
  );
}
