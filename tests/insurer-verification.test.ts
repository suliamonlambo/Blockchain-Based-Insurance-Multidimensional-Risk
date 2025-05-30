// Insurer Verification Contract Tests
import { describe, it, expect, beforeEach } from 'vitest';

// Mock Clarity contract interaction
class MockClarityContract {
  constructor() {
    this.storage = new Map();
    this.nextId = 1;
    this.blockHeight = 1000;
    this.txSender = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';
  }
  
  callPublic(functionName, args) {
    switch (functionName) {
      case 'register-insurer':
        return this.registerInsurer(...args);
      case 'verify-insurer':
        return this.verifyInsurer(...args);
      default:
        throw new Error(`Unknown function: ${functionName}`);
    }
  }
  
  callReadOnly(functionName, args) {
    switch (functionName) {
      case 'get-insurer':
        return this.getInsurer(...args);
      case 'is-verified-insurer':
        return this.isVerifiedInsurer(...args);
      case 'get-insurer-id':
        return this.getInsurerId(...args);
      default:
        throw new Error(`Unknown function: ${functionName}`);
    }
  }
  
  registerInsurer(name, licenseNumber, riskCategories, capitalRequirement) {
    const insurerId = this.nextId++;
    const insurer = {
      principal: this.txSender,
      name,
      licenseNumber,
      verificationStatus: false,
      riskCategories,
      capitalRequirement,
      createdAt: this.blockHeight
    };
    
    this.storage.set(`insurer-${insurerId}`, insurer);
    this.storage.set(`principal-${this.txSender}`, insurerId);
    
    return { type: 'ok', value: insurerId };
  }
  
  verifyInsurer(insurerId) {
    const insurer = this.storage.get(`insurer-${insurerId}`);
    if (!insurer) {
      return { type: 'err', value: 102 }; // ERR_NOT_FOUND
    }
    
    insurer.verificationStatus = true;
    this.storage.set(`insurer-${insurerId}`, insurer);
    
    return { type: 'ok', value: true };
  }
  
  getInsurer(insurerId) {
    const insurer = this.storage.get(`insurer-${insurerId}`);
    return insurer ? { type: 'some', value: insurer } : { type: 'none' };
  }
  
  isVerifiedInsurer(principal) {
    const insurerId = this.storage.get(`principal-${principal}`);
    if (!insurerId) return false;
    
    const insurer = this.storage.get(`insurer-${insurerId}`);
    return insurer ? insurer.verificationStatus : false;
  }
  
  getInsurerId(principal) {
    const insurerId = this.storage.get(`principal-${principal}`);
    return insurerId ? { type: 'some', value: { insurerId } } : { type: 'none' };
  }
}

describe('Insurer Verification Contract', () => {
  let contract;
  
  beforeEach(() => {
    contract = new MockClarityContract();
  });
  
  describe('register-insurer', () => {
    it('should register a new insurer successfully', () => {
      const result = contract.callPublic('register-insurer', [
        'Test Insurance Co',
        'LIC123456',
        ['auto', 'home', 'life'],
        1000000
      ]);
      
      expect(result.type).toBe('ok');
      expect(result.value).toBe(1);
    });
    
    it('should store insurer data correctly', () => {
      contract.callPublic('register-insurer', [
        'Test Insurance Co',
        'LIC123456',
        ['auto', 'home'],
        1000000
      ]);
      
      const insurer = contract.callReadOnly('get-insurer', [1]);
      expect(insurer.type).toBe('some');
      expect(insurer.value.name).toBe('Test Insurance Co');
      expect(insurer.value.licenseNumber).toBe('LIC123456');
      expect(insurer.value.verificationStatus).toBe(false);
    });
    
    it('should increment insurer ID for multiple registrations', () => {
      const result1 = contract.callPublic('register-insurer', [
        'Insurance Co 1',
        'LIC111',
        ['auto'],
        500000
      ]);
      
      const result2 = contract.callPublic('register-insurer', [
        'Insurance Co 2',
        'LIC222',
        ['home'],
        750000
      ]);
      
      expect(result1.value).toBe(1);
      expect(result2.value).toBe(2);
    });
  });
  
  describe('verify-insurer', () => {
    beforeEach(() => {
      contract.callPublic('register-insurer', [
        'Test Insurance Co',
        'LIC123456',
        ['auto', 'home'],
        1000000
      ]);
    });
    
    it('should verify an existing insurer', () => {
      const result = contract.callPublic('verify-insurer', [1]);
      expect(result.type).toBe('ok');
      expect(result.value).toBe(true);
    });
    
    it('should update verification status', () => {
      contract.callPublic('verify-insurer', [1]);
      
      const insurer = contract.callReadOnly('get-insurer', [1]);
      expect(insurer.value.verificationStatus).toBe(true);
    });
    
    it('should return error for non-existent insurer', () => {
      const result = contract.callPublic('verify-insurer', [999]);
      expect(result.type).toBe('err');
      expect(result.value).toBe(102); // ERR_NOT_FOUND
    });
  });
  
  describe('is-verified-insurer', () => {
    beforeEach(() => {
      contract.callPublic('register-insurer', [
        'Test Insurance Co',
        'LIC123456',
        ['auto'],
        1000000
      ]);
    });
    
    it('should return false for unverified insurer', () => {
      const result = contract.callReadOnly('is-verified-insurer', [contract.txSender]);
      expect(result).toBe(false);
    });
    
    it('should return true for verified insurer', () => {
      contract.callPublic('verify-insurer', [1]);
      
      const result = contract.callReadOnly('is-verified-insurer', [contract.txSender]);
      expect(result).toBe(true);
    });
    
    it('should return false for non-existent principal', () => {
      const result = contract.callReadOnly('is-verified-insurer', ['ST2UNKNOWN']);
      expect(result).toBe(false);
    });
  });
  
  describe('get-insurer-id', () => {
    it('should return insurer ID for registered principal', () => {
      contract.callPublic('register-insurer', [
        'Test Insurance Co',
        'LIC123456',
        ['auto'],
        1000000
      ]);
      
      const result = contract.callReadOnly('get-insurer-id', [contract.txSender]);
      expect(result.type).toBe('some');
      expect(result.value.insurerId).toBe(1);
    });
    
    it('should return none for unregistered principal', () => {
      const result = contract.callReadOnly('get-insurer-id', ['ST2UNKNOWN']);
      expect(result.type).toBe('none');
    });
  });
});

console.log('Running Insurer Verification Contract Tests...');
