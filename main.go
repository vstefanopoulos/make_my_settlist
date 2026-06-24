package main

import (
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"
)

var piano = []string{
	"Piano",
	"Lead sheet",
	"Keyboard",
	"Organ",
	"Orgel",
	"Concert",
	"Piano Muse",
	"Keys",
	"Full Score",
}

var bass = []string{
	"bass guitar",
	"lead sheet",
	"piano",
	"Keyboard",
	"Organ",
	"Orgel",
	"Concert",
	"Piano Muse",
	"Keys",
	"Full Score",
}

var copiedFiles []string // Collect copied file names

func main() {
	pianoFlag := flag.Bool("piano", false, "Use piano keywords")
	bassFlag := flag.Bool("bass", false, "Use bass keywords")
	targetFlag := flag.String("target", "", "Output folder (defaults to Desktop)")
	flag.Parse()

	if flag.NArg() < 1 {
		fmt.Println("Usage: go run main.go [-piano|-bass] <absolute_folder_path>")
		return
	}

	if !*pianoFlag && !*bassFlag {
		fmt.Println("Error: specify either -piano or -bass flag.")
		return
	}
	if *pianoFlag && *bassFlag {
		fmt.Println("Error: specify only one of -piano or -bass.")
		return
	}

	var keywords []string
	if *pianoFlag {
		keywords = piano
	} else {
		keywords = bass
	}

	inputPath := flag.Arg(0)
	info, err := os.Stat(inputPath)
	if err != nil || !info.IsDir() || !filepath.IsAbs(inputPath) {
		fmt.Println("Error: Provide a valid absolute folder path.")
		return
	}

	baseName := filepath.Base(inputPath)
	date := time.Now().Format("2006-01-02")
	baseOutputDir := getDesktopPath()
	if *targetFlag != "" {
		baseOutputDir = *targetFlag
	}
	outputFolder := filepath.Join(baseOutputDir, baseName+"_"+date)

	err = os.MkdirAll(outputFolder, 0755)
	if err != nil {
		fmt.Println("Failed to create output folder:", err)
		return
	}

	err = copyTopLevelPDFs(inputPath, outputFolder)
	if err != nil {
		fmt.Println("Error copying top-level PDFs:", err)
		return
	}

	// Process 1st-level subfolders
	firstLevelEntries, _ := os.ReadDir(inputPath)
	for _, entry := range firstLevelEntries {
		if !entry.IsDir() {
			continue
		}
		subfolderPath := filepath.Join(inputPath, entry.Name())
		found := copyMatchingPDFs(subfolderPath, outputFolder, entry.Name(), keywords)

		if !found {
			// Process 2nd-level subfolders
			secondLevelEntries, _ := os.ReadDir(subfolderPath)
			for _, subEntry := range secondLevelEntries {
				if !subEntry.IsDir() {
					continue
				}
				secondSubfolderPath := filepath.Join(subfolderPath, subEntry.Name())
				found = copyMatchingPDFs(secondSubfolderPath, outputFolder, entry.Name(), keywords)
			}
		}
		if !found {
			fmt.Println("No Results found on folder:", entry.Name())
		}
	}

	fmt.Println("PDFs copied to:", outputFolder)

	// Check for missing enumeration
	// checkMissingEnumerations()
}

// Copy top-level PDFs
func copyTopLevelPDFs(srcDir, destDir string) error {
	entries, err := os.ReadDir(srcDir)
	if err != nil {
		return err
	}
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		if strings.HasSuffix(strings.ToLower(entry.Name()), ".pdf") {
			srcFile := filepath.Join(srcDir, entry.Name())
			destFile := filepath.Join(destDir, entry.Name())
			err := copyFile(srcFile, destFile)
			if err == nil {
				copiedFiles = append(copiedFiles, entry.Name())
			}
		}
	}
	return nil
}

// Copy matching PDFs or the only PDF, prefixing with folder name
func copyMatchingPDFs(folderPath, outputFolder, prefix string, keywords []string) bool {
	pdfFiles := listPDFFiles(folderPath)
	if len(pdfFiles) == 0 {
		return false
	}

	found := false
	for _, file := range pdfFiles {
		match := false
		for _, suf := range keywords {
			if strings.Contains(strings.ToLower(file.Name()), strings.ToLower(suf)) {
				match = true
				break
			}
		}

		if match || len(pdfFiles) == 1 {
			srcFile := filepath.Join(folderPath, file.Name())
			destName := fmt.Sprintf("%s %s", prefix, file.Name())
			destFile := filepath.Join(outputFolder, destName)
			err := copyFile(srcFile, destFile)
			if err == nil {
				copiedFiles = append(copiedFiles, destName)
			}
			found = true
		}
	}
	return found
}

func listPDFFiles(dir string) []os.DirEntry {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil
	}
	var pdfs []os.DirEntry
	for _, entry := range entries {
		if !entry.IsDir() && strings.HasSuffix(strings.ToLower(entry.Name()), ".pdf") {
			pdfs = append(pdfs, entry)
		}
	}
	return pdfs
}

func copyFile(src, dest string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()

	out, err := os.Create(dest)
	if err != nil {
		return err
	}
	defer out.Close()

	_, err = io.Copy(out, in)
	return err
}

func getDesktopPath() string {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return "./"
	}
	return filepath.Join(homeDir, "Desktop")
}

// Check for missing enumeration numbers like 1.1, 1.2, etc.
// func checkMissingEnumerations() {
// 	enumRegex := regexp.MustCompile(`^(\d+)\.(\d+)`)
// 	groups := make(map[string][]int)

// 	for _, file := range copiedFiles {
// 		match := enumRegex.FindStringSubmatch(file)
// 		if len(match) != 3 {
// 			continue
// 		}
// 		group := match[1]
// 		number, _ := strconv.Atoi(match[2])
// 		groups[group] = append(groups[group], number)
// 	}

// 	for group, nums := range groups {
// 		sort.Ints(nums)
// 		for i := 1; i <= nums[len(nums)-1]; i++ {
// 			if !contains(nums, i) {
// 				fmt.Printf("⚠️ Missing file with enumeration: %s.%d\n", group, i)
// 			}
// 		}
// 	}
// }

// func contains(slice []int, val int) bool {
// 	return slices.Contains(slice, val)
// }
