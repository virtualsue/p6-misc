package main

import (
	"flag"
	"fmt"
	"github.com/asaskevich/govalidator"
	"golang.org/x/net/html"
	"log"
	"net/http"
	"net/url"
	"strings"
	"sync"
)

type PgResults struct {
	Link     string
	Children []string
}

// Package globals for ease in changing program defaults.
// These would be in a config file, data store etc in a 'real' program.
const (
	DEFAULT_DOMAIN string = "http://localhost:20000"
	MAX_CONCURRENT int    = 20
)

func main() {
	var (
		start_domain   string
		max_concurrent int
		wg             sync.WaitGroup
	)
	// Command line option processing. User allowed to override the pkg globals.
	flag.StringVar(&start_domain, "domain", DEFAULT_DOMAIN,
		"Specify the domain to crawl. E.g. http://flibble.co.uk.")
	flag.IntVar(&max_concurrent, "max-concurrent", MAX_CONCURRENT,
		"Specify the number of maximum # of concurrent processes to use. [1-50]")
	flag.Parse()

	res, errmsg := validateCmdLineOpts(start_domain, max_concurrent)
	if res == false {
		log.Fatal(errmsg)
	}

	log.Println("Crawling domain", start_domain)

	//tokens: buffered channel used to limit # of concurrent go routines
	var tokens = make(chan int, max_concurrent)

	// worklist: channel containing batches of urls to feed to crawl go routines
	worklist := make(chan []string)

	// visited: map of urls which have already been crawled
	visited := make(map[string]bool)

	// Seed the worklist chan with the start_domain
	crawl_indicator := 1
	start_arg := []string{start_domain}
	wg.Add(1)
	go func() { worklist <- start_arg; defer wg.Done() }()

	// Keep spidering until crawl_indicator drops to 0
	for ; crawl_indicator > 0; crawl_indicator-- {
		list := <-worklist
		for _, link := range list {
			if !visited[link] {
				visited[link] = true
				crawl_indicator++
				wg.Add(1)
				go func(link string) {
					defer wg.Done()
					tokens <- 1 // Acquire a token
					urls := crawl(link, start_domain)

					// Get URLs from this site
					var next_batch []string
					for url, follow := range urls {
						if follow {
							next_batch = append(next_batch, url)
						}
					}
					worklist <- next_batch

					// Gather results
					all_urls := getMapKeys(urls)
					//log.Printf("%v", PgResults{Link: link, Children: all_urls})
					log.Println("Link ", link, "# children ", len(all_urls))
					<-tokens // Release the token

				}(link)
			}
		}
	}

	wg.Wait()
}

// The crawl function takes a url and the domain that is to be crawled.
// It returns two maps, one contains urls of pages linked to in the input url
// and the other contains page assets (js, css, image links etc) it finds. It returns
// these items in a map type so that they are de-duplicated. Further, the
// urls map value is a boolean which indicates whether the key url is in the
// same domain. Urls which are found that are not in the same domain as the
// start url (start_domain) will not themselves be crawled.
func crawl(url, start_domain string) map[string]bool {
	urls := make(map[string]bool)

	resp, err := http.Get(url)
	if err != nil {
		log.Fatal(err)
	}
	defer resp.Body.Close()
	// Check response HTTP status
	if resp.StatusCode != 200 {
		return nil
	}

	tokenizer := html.NewTokenizer(resp.Body)
	not_done := true
	for not_done {
		next_token := tokenizer.Next()
		switch next_token {
		case html.ErrorToken:
			// End of tokens, exit loop
			not_done = false
		case html.StartTagToken:
			token := tokenizer.Token()
			is_url := false
			var attr_val string
			switch strings.ToLower(token.Data) {
			case "a":
				attr_val = getAttrVal(token, "href")
				is_url = true
			case "script":
				attr_val = getAttrVal(token, "src")
			case "img":
				attr_val = getAttrVal(token, "src")
			case "link":
				attr_val = getAttrVal(token, "href")
			default:
				continue
			}
			if attr_val != "" {
				new_url := processUrl(attr_val, start_domain)
				if is_url == true {
					urls[new_url] = false
					if strings.HasPrefix(new_url, start_domain) {
						urls[new_url] = true
					}
				}
			} else {
				// log.Printf("Token %s didn't have a detectable url value: ignored", token.Data)
			}
		}
	}
	return urls
}

func getAttrVal(token html.Token, name string) string {
	for _, attr := range token.Attr {
		if strings.ToLower(attr.Key) == name {
			return attr.Val
		}
	}
	// Not found
	return ""
}

// processUrl uses net/url to resolve new_url to absolute URI
func processUrl(new_url, domain string) string {
	u, err := url.Parse(new_url)
	if err != nil {
		log.Println("URL from page so damaged even url.Parse won't handle it -", err)
		return ""
	}
	base, err := url.Parse(domain)
	if err != nil {
		log.Fatal("Should never happen, domain validated earlier -", err)
	}
	processed := base.ResolveReference(u)
	processed.Fragment = ""
	processed.RawQuery = ""
	return processed.String()
}

// Used to extract, return keys from urls maps
func getMapKeys(res map[string]bool) []string {
	keys := make([]string, len(res))
	i := 0
	for key, _ := range res {
		keys[i] = key
		i++
	}
	return keys
}

// Basic validation of the command line parameters
func validateCmdLineOpts(start_domain string, max_concurrent int) (bool, string) {
	if govalidator.IsURL(start_domain) == false {
		return false, fmt.Sprintf("Please specify a valid URL to crawl. You entered %s.\n", start_domain)
	}
	// We only need to confirm if start_domain starts with http.
	// govalidator validates absolute and non-absolute URLs. If an absolute URL
	// is entered in a illegal format, govalidator will catch it.
	if strings.HasPrefix(start_domain, "http") == false {
		return false, fmt.Sprintf("The domain name must be in the form http[s]://name.xx. You entered %s.\n", start_domain)
	}
	if max_concurrent < 1 || max_concurrent > 50 {
		return false, fmt.Sprintf("Max concurrent process value must be between 1 and 50. You entered %d.\n", max_concurrent)
	}
	return true, ""
}
