
#include <sstream>
#include <functional>
#include <iostream>
#include <fstream>
#include <exception>

// if you want to debug this file, pass the debug to true
#ifndef DEBUG
#define DEBUG false
#endif
#define PRINT_DEBUG(mes)    (DEBUG) ? mes : std::cerr

static std::string const QUOTE = "\"";
static std::string const SEP = ";";
static std::string const EOL = "\n";

// Do a strncmp on two strings
static bool compare(std::string const &s1, size_t i, std::string const &s2) {
    return !s1.compare(i, s2.length(), s2);
}

//  Return an index to the first occurrence of the character c after index i in the string str
static size_t goToNextChar(std::string const &str, size_t i, std::string const &c) {
    while (i < str.length() && !compare(str, i, c)) {
        ++i;
    }
    return i < str.length() ? i : std::string::npos;
}

// Return the number of columns refer to the csv header 
static int getNbColumns(std::istream &file) {
    std::string line;
    std::getline(file, line);

    if (line.back() == '\r')
        line.pop_back();
    if (!compare(line, 0, QUOTE))
        throw std::runtime_error{"malformed header."};

    size_t i = 0;
    int n = 0;
    do {
        i = goToNextChar(line, i+1, QUOTE);
        if (i == std::string::npos)
            break;
        ++n;
        ++i;
        if (i < line.length() && !compare(line, i, SEP))
            throw std::runtime_error{"malformed header."};
        i = goToNextChar(line, i, QUOTE);
    } while (i != std::string::npos);
    std::cout << line << EOL;
    return n;
}

// Print the row and clear it
static void flushRow(std::string &row) {
    std::cout << row << EOL;
    row.clear();
}

// Stack all lines until a possible row's end was found and return it
static void getBlock(std::ifstream &file, std::string &block) {
    std::string line;
    bool r = false;

    while (std::getline(file, line)) {
        r = true;
        if (line.back() == '\r')
            line.pop_back();
        block += line;
        block += EOL;
        if (line.length() >= QUOTE.length() && compare(line, line.length()-QUOTE.length(), QUOTE)) {
            break;
        }
    }
    if (!r && !block.empty())
        throw std::runtime_error{"unexpected EOF."};
}

// Return the number of fields found in the given block
static int getNbSections(std::string const &row) {
    bool inQuotes = false;
    int n = 0;

    for (size_t i = 0; i < row.length(); ++i) {
        if (!inQuotes && compare(row, i, QUOTE) && (i == 0 || compare(row, i - SEP.length(), SEP))) { // enter in quotes

            PRINT_DEBUG(std::cerr << "enter in quotes : " << i << std::endl);
            inQuotes = true;

        } else if (inQuotes && compare(row, i, QUOTE+QUOTE)) { // If found `""' in quoted field

            ++i;

        } else if (inQuotes && compare(row, i, QUOTE)) { // exit out of quotes

            PRINT_DEBUG(std::cerr << "exit in quotes : " << i << std::endl);
            inQuotes = false;

        } else if (!inQuotes && compare(row, i, SEP)) { // Count the number of SEP outside of quoted field

            PRINT_DEBUG(std::cerr << "pos : " << i << std::endl);
            ++n;

        }
    }
    PRINT_DEBUG(std::cerr << "\n\n" << std::endl);
    return  n+1; // Add the last field
}

// Generate a valid row with a given block and return it
static std::string escapeInvalidQuotes(std::string const &row) {
    std::stringstream sstr;
    bool inQuotes = false;

    for (size_t i = 0; i < row.length(); ++i) {
        if (!inQuotes && compare(row, i, QUOTE) && (i == 0 || compare(row, i - SEP.length(), SEP))) { // enter in quotes

            inQuotes = true;

        } else if (inQuotes && compare(row, i, QUOTE+QUOTE)) { // `""' => `\"'

            sstr << "\\";
            ++i;

        } else if (inQuotes && compare(row, i, QUOTE)) { // exit out of quotes

            inQuotes = false;

        } else if (inQuotes && compare(row, i, "\\")) { // `\' => `\\'
            sstr << '\\';
        }
        sstr << row[i]; // Stack the char
    }
    return sstr.str();
}

// get the next row. if more than nmax sections were found, throw an error
static void getRow(std::ifstream &file, int nmax, std::string &row) {
    std::string line;

    std::string prerow = row;
    int n = -1;
    do {
        getBlock(file, prerow);
        if (prerow.empty())
            break;
        n = getNbSections(prerow);
    } while (n < nmax);

    if (n > nmax)
        throw std::runtime_error{std::string("<<") + prerow + ">>, found " + std::to_string(n) + " sections."};
    if (n != -1)
        row = escapeInvalidQuotes(prerow);
}

// Generate all rows
static void process(std::ifstream &file, int nmax) {
    std::string row;

    while (true) {
        getRow(file, nmax, row);
        if (row.empty())
            break;
        flushRow(row);
    }
}

int main(int ac, char **av)
try {
    if (ac == 1) {
        std::cerr << "USAGE : " << *av << " filename.csv [--header | --column number]" << std::endl;
        return 1;
    }
    std::ifstream file{av[1]};

    if (file.fail())
        throw std::runtime_error{std::string("fail to open ") + av[1]};

    int n;
    if (ac == 3 && av[2] == std::string("--header")) {
        n = getNbColumns(file);
    } else if (ac == 4 && av[2] == std::string("--column")) {
        n = atoi(av[3]);
    } else {
        std::cerr << "USAGE : " << *av << "filename.csv [--header | --column number]" << std::endl;
        return 1;
    }
    if (n <= 0)
        throw std::runtime_error{"invalid number of columns : got " + std::to_string(n)};

    process(file, n);
    return 0;
} catch (std::exception const &e) {
    std::cerr << "ERROR : " << e.what() << std::endl;
    return 2;
}