import { ethers } from 'ethers';
import { 
  AGENT_IDENTITY_ABI, 
  SOULBOUND_RESUME_ABI, 
  CONTRACT_ADDRESSES 
} from './contracts';

export interface AgentData {
  serviceUrl: string;
  category: string;
  paymentAddress: string;
}

export interface JobRecord {
  jobId: bigint;
  employer: string;
  jobType: number;
  status: number;
  timestamp: bigint;
  value: bigint;
  proofHash: string;
  proofUri: string;
  description: string;
  success: boolean;
  tag1: string;
  tag2: string;
}

export interface AgentStats {
  totalJobs: bigint;
  successfulJobs: bigint;
  failedJobs: bigint;
  reputation: bigint;
}

export interface AgentProfile {
  agentId: string;
  owner: string;
  agentData: AgentData;
  stats: AgentStats;
  jobs: JobRecord[];
  resumeId: bigint;
  isRegistered: boolean;
}

export class BlockchainService {
  private provider: ethers.JsonRpcProvider;
  private agentIdentityContract: ethers.Contract;
  private soulboundResumeContract: ethers.Contract;

  constructor(rpcUrl: string = 'http://127.0.0.1:8545') {
    this.provider = new ethers.JsonRpcProvider(rpcUrl);
    this.agentIdentityContract = new ethers.Contract(
      CONTRACT_ADDRESSES.AgentIdentity,
      AGENT_IDENTITY_ABI,
      this.provider
    );
    this.soulboundResumeContract = new ethers.Contract(
      CONTRACT_ADDRESSES.SoulboundResume,
      SOULBOUND_RESUME_ABI,
      this.provider
    );
  }

  async getAgentProfile(agentId: string): Promise<AgentProfile> {
    try {
      // Check if agent is registered
      const isRegistered = await this.agentIdentityContract.isRegistered(agentId);
      
      if (!isRegistered) {
        throw new Error(`Agent ID ${agentId} is not registered`);
      }

      // Fetch agent data
      const owner = await this.agentIdentityContract.ownerOf(agentId);
      const agentData = await this.agentIdentityContract.getAgentData(agentId);
      
      // Fetch resume data
      const resumeId = await this.soulboundResumeContract.getResumeId(agentId);
      
      // Fetch stats
      const stats = await this.soulboundResumeContract.getAgentStats(agentId);
      
      // Fetch job records
      let jobs: JobRecord[] = [];
      try {
        const jobRecords = await this.soulboundResumeContract.getJobRecords(agentId);
        jobs = jobRecords.map((job: any) => ({
          jobId: job.jobId,
          employer: job.employer,
          jobType: job.jobType,
          status: job.status,
          timestamp: job.timestamp,
          value: job.value,
          proofHash: job.proofHash,
          proofUri: job.proofUri,
          description: job.description,
          success: job.success,
          tag1: job.tag1,
          tag2: job.tag2
        }));
      } catch (error) {
        console.log('No resume found or no jobs yet');
      }

      return {
        agentId,
        owner,
        agentData: {
          serviceUrl: agentData.serviceUrl,
          category: agentData.category,
          paymentAddress: agentData.paymentAddress
        },
        stats: {
          totalJobs: stats[0],
          successfulJobs: stats[1],
          failedJobs: stats[2],
          reputation: stats[3]
        },
        jobs,
        resumeId,
        isRegistered
      };
    } catch (error: any) {
      console.error('Error fetching agent profile:', error);
      throw error;
    }
  }

  async isProviderConnected(): Promise<boolean> {
    try {
      await this.provider.getNetwork();
      return true;
    } catch {
      return false;
    }
  }
}
