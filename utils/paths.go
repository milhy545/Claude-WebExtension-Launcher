package utils

import (
	"os"
	"path/filepath"
	"runtime"
)

var execDir string

func init() {
	execPath, err := os.Executable()
	if err != nil {
		panic("Failed to get executable path: " + err.Error())
	}
	execDir = filepath.Dir(execPath)
}

func GetExecutableDir() string {
	return execDir
}

func ResolvePath(relativePath string) string {
	if runtime.GOOS == "darwin" {
		// On macOS, use Application Support directory instead of bundle
		home, _ := os.UserHomeDir()
		dataDir := filepath.Join(home, "Library", "Application Support", "Claude WebExtension Launcher")
		os.MkdirAll(dataDir, 0755)
		return filepath.Join(dataDir, relativePath)
	} else if runtime.GOOS == "linux" {
		// On Linux, use XDG Base Directory Specification
		dataHome := os.Getenv("XDG_DATA_HOME")
		if dataHome == "" {
			home, _ := os.UserHomeDir()
			dataHome = filepath.Join(home, ".local", "share")
		}
		dataDir := filepath.Join(dataHome, "claude-webext-launcher")
		os.MkdirAll(dataDir, 0755)
		return filepath.Join(dataDir, relativePath)
	}
	// Windows and other platforms: use executable directory
	return filepath.Join(execDir, relativePath)
}

// GetConfigPath returns the configuration directory path
func GetConfigPath() string {
	if runtime.GOOS == "linux" {
		configHome := os.Getenv("XDG_CONFIG_HOME")
		if configHome == "" {
			home, _ := os.UserHomeDir()
			configHome = filepath.Join(home, ".config")
		}
		configDir := filepath.Join(configHome, "claude-webext-launcher")
		os.MkdirAll(configDir, 0755)
		return configDir
	}
	return ResolvePath("")
}

// GetCachePath returns the cache directory path
func GetCachePath() string {
	if runtime.GOOS == "linux" {
		cacheHome := os.Getenv("XDG_CACHE_HOME")
		if cacheHome == "" {
			home, _ := os.UserHomeDir()
			cacheHome = filepath.Join(home, ".cache")
		}
		cacheDir := filepath.Join(cacheHome, "claude-webext-launcher")
		os.MkdirAll(cacheDir, 0755)
		return cacheDir
	}
	return ResolvePath("")
}
