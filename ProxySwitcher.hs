{-# LANGUAGE ScopedTypeVariables #-}
-- 2013-05-01
module Main (
  keyStr,
  openIEKey,
  isProxyEnable,
  getProxyServer,
  setProxyIs,
  setProxyServer,
  CmdOpt(..),
  cmdParser,
  printCurrentSettings,
  b2ed,
  main',
  main)
  where

import Foreign
import Foreign.C
import System.Win32
import Text.Printf
import Control.Monad (when)
import Graphics.Win32
import Options.Applicative -- package optparse-applicative

keyStr = "Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings"

openIEKey = regOpenKey hKEY_CURRENT_USER keyStr

-- |プロキシは有効か？
isProxyEnable :: IO Bool
isProxyEnable = do
  key <- openIEKey
  ptr <- malloc
  regQueryValueEx key "ProxyEnable" ptr $ sizeOf (undefined :: DWORD)
  b <- peek ptr
  free ptr
  regCloseKey key
  return $ case b of
    0 -> False
    1 -> True

-- |現在設定されているプロキシサーバは？
getProxyServer :: IO String
getProxyServer = do
  key <- openIEKey
  serverAddr <- regQueryValue key $ Just "ProxyServer"
  regCloseKey key
  return serverAddr

-- |プロキシ有効フラグの変更
setProxyIs :: Bool -> IO ()
setProxyIs b = do
  key <- openIEKey
  let b' = case b of
            True -> 1
            False -> 0
  ptr :: Ptr DWORD <- malloc
  poke ptr b'
  regSetValueEx key "ProxyEnable" rEG_DWORD (castPtr ptr) $ sizeOf (undefined :: DWORD)
  free ptr
  regCloseKey key

-- |プロキシサーバを設定
setProxyServer :: String -> IO ()
setProxyServer host = do
  key <- openIEKey
  regSetValue key "ProxyServer" host
  regCloseKey key
  
-- |コマンドライン引数
data CmdOpt = CmdOpt
  { host :: String,
    checkOnly :: Bool
  }

-- |コマンドライン引数パーサ
cmdParser :: Parser CmdOpt
cmdParser = CmdOpt
  <$> strOption
      ( long "proxy" <>
        short 'p' <>
        metavar "PROXY:PORT" <>
        help "Specify proxy server" <>
        value "" )
  <*> switch
      ( long "check-only" <>
        short 'c' <>
        help "Only print settings" )
        
-- |現在の設定を表示
printCurrentSettings :: IO ()
printCurrentSettings = do
  b <- isProxyEnable
  host <- getProxyServer
  printf "Proxy `%s` is %s.\n" host $ b2ed b

-- |Bool値を表示用に文字列に変換するユーティリティ
b2ed b = if b then "enable" else "disable" 
    
-- |メイン
main' :: CmdOpt -> IO ()
main' (CmdOpt "" chk) = do
  printCurrentSettings
  when (not chk) $ do
    b <- isProxyEnable
    setProxyIs $ not b
    printf "Proxy was %sd.\n" $ b2ed (not b)
main' (CmdOpt newHost chk) = do
  printCurrentSettings
  when (not chk) $ do
    setProxyIs True
    setProxyServer newHost
    printf "Proxy was set `%s` and enabled.\n" newHost

main = execParser opts >>= main' >> sendMessage (castUINTPtrToPtr 0xffff) wM_WININICHANGE 0 0
  where opts = info (helper <*> cmdParser)
          ( fullDesc <>
            progDesc "Proxy Swiching" <>
            header "ProxySwitcher" )
