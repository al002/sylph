use lazy_static::lazy_static;
use solana_sdk::{
    instruction::CompiledInstruction, message::Message, pubkey::Pubkey,
    system_instruction::SystemInstruction,
};
use solana_transaction_status::UiTransactionTokenBalance;
use spl_token::instruction::TokenInstruction;
use std::collections::HashMap;

lazy_static! {
    static ref KNOWN_PROGRAMS: HashMap<&'static str, &'static str> = {
        let mut m = HashMap::new();
        m.insert("11111111111111111111111111111111", "System Program");
        m.insert(
            "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA",
            "Token Program",
        );
        m.insert(
            "ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL",
            "Associated Token Program",
        );
        m.insert(
            "meta5YZgf5YscZgqDCqXv8oQL7UzDMhXQ6VBHxGgqYf",
            "Metaplex Token Metadata",
        );
        m.insert(
            "p1exdMJcjVao65QdewkaZRUnU6VPSXhus9n2GzWfh98",
            "Metaplex Candy Machine",
        );
        // DEX Programs
        // Serum
        m.insert(
            "9xQeWvG816bUx9EPjHmaT23yvVM2ZWbrrpZb9PusVFin",
            "Serum DEX v3",
        );

        // Raydium
        m.insert("675kPX9MHTjS2zt1qfr1NYHuzeLXfQM9H24wFSUt1Mp8", "Raydium Liquidity Pool V4");
        m.insert("5quBtoiQqxF9Jv6KYKctB59NT3gtJD2Y65kdnB1Uev3h", "Raydium Router V1");
        m.insert("CAMMCzo5YL8w4VFF8KVHrK22GGUsp5VTaW7grrKgrWqK", "Raydium Concentrated LP");
        // Jupiter
        m.insert("JUP4Fb2cqiRUcaTHdrPC8h2gNsA2ETXiPDD33WcGuJB", "Jupiter V4");
        m.insert("JUP6LkbZbjS1jKKwapdHNy74zcZ3tLUZoi5QNyVTaRk", "Jupiter V6");

        m
    };
}

#[derive(Debug)]
pub enum TransactionCategory {
    SystemProgram(SystemProgramType),
    TokenProgram(TokenProgramType),
    DexProgram(DexProgramType),
    NFTProgram(NFTProgramType),
    Unknown,
}

#[derive(Debug)]
pub enum SystemProgramType {
    CreateAccount,
    Transfer,
    Assign,
    Other,
}

#[derive(Debug)]
pub enum TokenProgramType {
    Transfer,
    MintTo,
    Burn,
    CreateAccount,
    Other,
}

#[derive(Debug)]
pub enum DexProgramType {
    // Serum
    SerumNewOrder,
    SerumMatchOrder,
    SerumCancelOrder,
    // Raydium
    RaydiumSwap,
    RaydiumAddLiquidity,
    RaydiumRemoveLiquidity,
    // Jupiter
    JupiterSwap,
    Other,
}

#[derive(Debug)]
pub enum NFTProgramType {
    Mint,
    Transfer,
    List,
    Other,
}

#[derive(Debug)]
pub struct TokenTransferInfo {
    pub from_address: String,
    pub to_address: String,
    pub amount: u64,
    pub mint: String,
    pub token_type: TokenType,
}

#[derive(Debug)]
pub enum TokenType {
    SPL,
    NFT,
}

pub struct InstructionParser;

impl InstructionParser {
    pub fn is_dex_program(program_id: &Pubkey) -> bool {
        let program_id_str = program_id.to_string();
        matches!(
            program_id_str.as_str(),
            // Serum
            "9xQeWvG816bUx9EPjHmaT23yvVM2ZWbrrpZb9PusVFin" |
            // Raydium
            "675kPX9MHTjS2zt1qfr1NYHuzeLXfQM9H24wFSUt1Mp8" |
            "5quBtoiQqxF9Jv6KYKctB59NT3gtJD2Y65kdnB1Uev3h" |
            "CAMMCzo5YL8w4VFF8KVHrK22GGUsp5VTaW7grrKgrWqK" |
            // Jupiter
            "JUP4Fb2cqiRUcaTHdrPC8h2gNsA2ETXiPDD33WcGuJB" |
            "JUP6LkbZbjS1jKKwapdHNy74zcZ3tLUZoi5QNyVTaRk"
        )
    }

    pub fn parse_instruction(
        ix: &CompiledInstruction,
        message: &Message,
    ) -> (String, HashMap<String, String>) {
        let program_id = message.account_keys[ix.program_id_index as usize].to_string();

        match program_id.as_str() {
            // System Program
            "11111111111111111111111111111111" => Self::parse_system_instruction(ix, message),
            // Token Program
            "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA" => {
                Self::parse_token_instruction(ix, message)
            }
            // Add more program parsing here
            _ => ("Unknown".to_string(), HashMap::new()),
        }
    }

    fn parse_system_instruction(
        ix: &CompiledInstruction,
        message: &Message,
    ) -> (String, HashMap<String, String>) {
        let mut parsed_data = HashMap::new();

        if let Ok(system_ix) = bincode::deserialize::<SystemInstruction>(&ix.data) {
            match system_ix {
                SystemInstruction::CreateAccount {
                    lamports,
                    space,
                    owner,
                } => {
                    parsed_data.insert("lamports".to_string(), lamports.to_string());
                    parsed_data.insert("space".to_string(), space.to_string());
                    parsed_data.insert("owner".to_string(), owner.to_string());
                    ("CreateAccount".to_string(), parsed_data)
                }
                SystemInstruction::Transfer { lamports } => {
                    parsed_data.insert("lamports".to_string(), lamports.to_string());
                    ("Transfer".to_string(), parsed_data)
                }
                // Add more system instruction parsing
                _ => ("Unknown".to_string(), parsed_data),
            }
        } else {
            ("Invalid".to_string(), parsed_data)
        }
    }

    fn parse_token_instruction(
        ix: &CompiledInstruction,
        _message: &Message,
    ) -> (String, HashMap<String, String>) {
        let mut parsed_data = HashMap::new();

        if let Ok(token_ix) = TokenInstruction::unpack(&ix.data) {
            match token_ix {
                TokenInstruction::Transfer { amount } => {
                    parsed_data.insert("amount".to_string(), amount.to_string());
                    ("Transfer".to_string(), parsed_data)
                }
                TokenInstruction::MintTo { amount } => {
                    parsed_data.insert("amount".to_string(), amount.to_string());
                    ("MintTo".to_string(), parsed_data)
                }
                TokenInstruction::Burn { amount } => {
                    parsed_data.insert("amount".to_string(), amount.to_string());
                    ("Burn".to_string(), parsed_data)
                }
                // Add more token instruction parsing
                _ => ("Unknown".to_string(), parsed_data),
            }
        } else {
            ("Invalid".to_string(), parsed_data)
        }
    }

    pub fn categorize_dex_instruction(program_id: &Pubkey, data: &[u8]) -> DexProgramType {
        let program_id_str = program_id.to_string();

        match program_id_str.as_str() {
            // Serum DEX
            "9xQeWvG816bUx9EPjHmaT23yvVM2ZWbrrpZb9PusVFin" => {
                // 根据 instruction data 的第一个字节判断指令类型
                match data.first() {
                    Some(0) => DexProgramType::SerumNewOrder,
                    Some(1) => DexProgramType::SerumMatchOrder,
                    Some(2) => DexProgramType::SerumCancelOrder,
                    _ => DexProgramType::Other,
                }
            }
            // Raydium
            "675kPX9MHTjS2zt1qfr1NYHuzeLXfQM9H24wFSUt1Mp8"
            | "5quBtoiQqxF9Jv6KYKctB59NT3gtJD2Y65kdnB1Uev3h"
            | "CAMMCzo5YL8w4VFF8KVHrK22GGUsp5VTaW7grrKgrWqK" => {
                // 根据 instruction data 判断 Raydium 操作类型
                match data.first() {
                    Some(1) => DexProgramType::RaydiumSwap,
                    Some(2) => DexProgramType::RaydiumAddLiquidity,
                    Some(3) => DexProgramType::RaydiumRemoveLiquidity,
                    _ => DexProgramType::Other,
                }
            }
            // Jupiter
            "JUP4Fb2cqiRUcaTHdrPC8h2gNsA2ETXiPDD33WcGuJB"
            | "JUP6LkbZbjS1jKKwapdHNy74zcZ3tLUZoi5QNyVTaRk" => {
                // Jupiter swap
                DexProgramType::JupiterSwap
            }
            _ => DexProgramType::Other,
        }
    }

    pub fn categorize_transaction(
        message: &Message,
        instructions: &[CompiledInstruction],
    ) -> TransactionCategory {
        let mut has_system_transfer = false;
        let mut has_token_transfer = false;
        let mut has_nft_operation = false;

        let mut has_serum_dex = false;
        let mut has_raydium = false;
        let mut has_jupiter = false;

        for ix in instructions {
            let program_id = message.account_keys[ix.program_id_index as usize].to_string();

            match program_id.as_str() {
                "11111111111111111111111111111111" => {
                    if let Ok(sys_ix) = bincode::deserialize::<SystemInstruction>(&ix.data) {
                        match sys_ix {
                            SystemInstruction::Transfer { .. } => has_system_transfer = true,
                            _ => (),
                        }
                    }
                }
                "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA" => {
                    if let Ok(token_ix) = TokenInstruction::unpack(&ix.data) {
                        match token_ix {
                            TokenInstruction::Transfer { .. } => has_token_transfer = true,
                            _ => (),
                        }
                    }
                }
                // Serum
                "9xQeWvG816bUx9EPjHmaT23yvVM2ZWbrrpZb9PusVFin" => {
                    has_serum_dex = true;
                }
                // Raydium
                "675kPX9MHTjS2zt1qfr1NYHuzeLXfQM9H24wFSUt1Mp8"
                | "5quBtoiQqxF9Jv6KYKctB59NT3gtJD2Y65kdnB1Uev3h"
                | "CAMMCzo5YL8w4VFF8KVHrK22GGUsp5VTaW7grrKgrWqK" => {
                    has_raydium = true;
                }
                // Jupiter
                "JUP4Fb2cqiRUcaTHdrPC8h2gNsA2ETXiPDD33WcGuJB"
                | "JUP6LkbZbjS1jKKwapdHNy74zcZ3tLUZoi5QNyVTaRk" => {
                    has_jupiter = true;
                }
                "meta5YZgf5YscZgqDCqXv8oQL7UzDMhXQ6VBHxGgqYf" => {
                    has_nft_operation = true;
                }
                _ => (),
            }
        }

        if has_jupiter {
            TransactionCategory::DexProgram(DexProgramType::JupiterSwap)
        } else if has_raydium {
            TransactionCategory::DexProgram(DexProgramType::RaydiumSwap)
        } else if has_serum_dex {
            TransactionCategory::DexProgram(DexProgramType::SerumNewOrder)
        } else {
            match (
                has_system_transfer,
                has_token_transfer,
                has_nft_operation,
            ) {
                (true, _, _,) => TransactionCategory::SystemProgram(SystemProgramType::Transfer),
                (_, true, _,) => TransactionCategory::TokenProgram(TokenProgramType::Transfer),
                (_, _, true) => TransactionCategory::NFTProgram(NFTProgramType::Other),
                _ => TransactionCategory::Unknown,
            }
        }
    }

    pub fn parse_token_transfers(
        message: &Message,
        instruction: &CompiledInstruction,
        accounts: &[Pubkey],
        pre_token_balances: Option<&Vec<UiTransactionTokenBalance>>,
        post_token_balances: Option<&Vec<UiTransactionTokenBalance>>,
    ) -> Option<TokenTransferInfo> {
        // is it Token Program
        if !Self::is_token_program(message.account_keys[instruction.program_id_index as usize]) {
            return None;
        }

        if let Ok(token_ix) = TokenInstruction::unpack(&instruction.data) {
            match token_ix {
                TokenInstruction::Transfer { amount } => {
                    // SPL Token transfer
                    let from_index = instruction.accounts[0] as usize;
                    let to_index = instruction.accounts[1] as usize;

                    let from_address = accounts[from_index].to_string();
                    let to_address = accounts[to_index].to_string();

                    // Get token mint address
                    let mint = Self::find_token_mint(
                        from_address.clone(),
                        pre_token_balances,
                        post_token_balances,
                    )?;

                    let token_type = if amount == 1 && Self::is_nft_mint(&mint, pre_token_balances)
                    {
                        TokenType::NFT
                    } else {
                        TokenType::SPL
                    };

                    Some(TokenTransferInfo {
                        from_address,
                        to_address,
                        amount,
                        mint,
                        token_type,
                    })
                }
                TokenInstruction::TransferChecked { amount, decimals } => {
                    let from_index = instruction.accounts[0] as usize;
                    let mint_index = instruction.accounts[1] as usize;
                    let to_index = instruction.accounts[2] as usize;

                    let from_address = accounts[from_index].to_string();
                    let to_address = accounts[to_index].to_string();
                    let mint = accounts[mint_index].to_string();

                    let token_type = if amount == 1 && decimals == 0 {
                        TokenType::NFT
                    } else {
                        TokenType::SPL
                    };

                    Some(TokenTransferInfo {
                        from_address,
                        to_address,
                        amount,
                        mint,
                        token_type,
                    })
                }
                _ => None,
            }
        } else {
            None
        }
    }

    fn is_token_program(program_id: Pubkey) -> bool {
        program_id == spl_token::id()
    }

    fn find_token_mint(
        token_account: String,
        pre_balances: Option<&Vec<UiTransactionTokenBalance>>,
        post_balances: Option<&Vec<UiTransactionTokenBalance>>,
    ) -> Option<String> {
        // 先从 pre balances 查找
        if let Some(balances) = pre_balances {
            if let Some(balance) = balances
                .iter()
                .find(|b| b.account_index.to_string() == token_account)
            {
                return Some(balance.mint.clone());
            }
        }

        // 再从 post balances 查找
        if let Some(balances) = post_balances {
            if let Some(balance) = balances
                .iter()
                .find(|b| b.account_index.to_string() == token_account)
            {
                return Some(balance.mint.clone());
            }
        }

        None
    }

    fn is_nft_mint(mint: &str, token_balances: Option<&Vec<UiTransactionTokenBalance>>) -> bool {
        // decimals is 0 and supply is 1
        if let Some(balances) = token_balances {
            if let Some(balance) = balances.iter().find(|b| b.mint == mint) {
                return balance.ui_token_amount.decimals == 0
                    && balance.ui_token_amount.amount == "1";
            }
        }
        false
    }
}
