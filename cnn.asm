.data
	inputFile: .asciiz "Test_cases/test_2.txt"
	outputFile: .asciiz "output_matrix.txt"
	space: .asciiz " "          # Space separator for printing
	newLine: .asciiz "\n"
	inputError: .asciiz "\nIinput is invalid, terminating...\n"
	float_val: .float 10.0      # Define a floating-point value in the data segment
	float_val2: .float 0.1      # Define a floating-point value in the data segment
.align 2
	fileWords: .space 1024      # Store the input string
	image: .space 1024     
	kernel: .space 1024
	paddedMatrix: .space 1024
	out: .space 1024
	

.text
    	la $a0, float_val       # Load address of float_val into $a0
    	l.s $f1, 0($a0)         # Load the float value from memory into $f1
    	la $a0, float_val2
    	l.s $f2, 0($a0)
    	la $a0, float_val2
    	l.s $f3, 0($a0)
    
.globl main

main:
    # HOW TO READ INTO A FILE
    li $v0, 13              # open_file syscall code = 13
    la $a0, inputFile        # get the file name
    li $a1, 0               # file flag = read (0)
    syscall
    move $s0, $v0           # save the file descriptor. $s0 = file
    
    # Read the file
    li $v0, 14              # read_file syscall code = 14
    move $a0, $s0           # file descriptor
    la $a1, fileWords       # The buffer that holds the string of the WHOLE file
    la $a2, 1024            # hardcoded buffer length
    syscall
    
    # Close the file
    li $v0, 16              # close_file syscall code
    move $a0, $s0           # file descriptor to close
    syscall

    # Now, extract the first number 
    la $t0, fileWords       # Load the address of fileWords (string buffer)
    lb $s0, 0($t0)          # Load the first byte (ASCII character '3')
    lb $s1, 2($t0)          # Second number
    lb $s2, 4($t0)          # Third
    lb $s3, 6($t0)          # Fourth
    
    # Convert ASCII characters to integers
    li $t5, 48              # ASCII value of '0' is 48
    sub $s0, $s0, $t5       # Convert ASCII to integer
    sub $s1, $s1, $t5
    sub $s2, $s2, $t5
    sub $s3, $s3, $t5
    
    # Store N, M, p, s into stack
    addi $sp, $sp, -4    
    sw $s0, 0($sp)          # Store $s0 (N)
    addi $sp, $sp, -4    
    sw $s1, 0($sp)          # Store $s1 (M)
    addi $sp, $sp, -4    
    sw $s2, 0($sp)          # Store $s2 (p)
    addi $sp, $sp, -4    
    sw $s3, 0($sp)          # Store $s3 (s)
    
    # Store necessary ASCII values in the stack
    li $t1, 10              # Store "\n"
    addi $sp, $sp, -4
    sw $t1, 0($sp)
    
    li $t1, 13              # Store "\r"
    addi $sp, $sp, -4
    sw $t1, 0($sp)
    
    li $t1, 32              # Store " "
    addi $sp, $sp, -4
    sw $t1, 0($sp)
    
    li $t1, 45              # Store "-"
    addi $sp, $sp, -4
    sw $t1, 0($sp)
    
    li $t1, 46              # Store "."
    addi $sp, $sp, -4
    sw $t1, 0($sp)

    la $t0, fileWords       # Address of the string
    addi $t0, $t0, 9        # Move to the 9th byte (first character of second line)
    la $t1, image     # Start of the image array

# Parsing and storing loop
parse_loop:
    lb $t2, 0($t0)          # Load the current character from fileWords
    
    # Compare with space
    lw $s0, 8($sp)         # Load " "
    beq $t2, $s0, skip_space
    
    # Compare with "\r"
    lw $s0, 12($sp)         # Load "\r"
    beq $t2, $s0, end_parse
    
    # Compare with "\n"
    lw $s0, 16($sp)          # Load "\n"
    beq $t2, $s0, end_parse
    
    # Initialize registers for parsing a float
    li $t4, 1               # Flag for decimal part
    li $t5, 1               # Multiplier for decimal places
    li $t6, 0               # Sign flag (0 = positive, 1 = negative)
    mtc1 $zero, $f12        # Clear $f12 float register
    
    # Check if the number is negative
    lw $s0, 4($sp)          # Load "-"
    beq $t2, $s0, set_negative
    
parse_digits:
    lb $t2, 0($t0)
    
    # Compare with "."
    lw $s0, 0($sp)          # Load "."
    beq $t2, $s0, decimal_part
    
    # Check if we should store the float
    lw $s0, 8($sp)         # Load " "
    beq $t2, $s0, store_float
    
    lw $s0, 12($sp)         # Load "\r"
    beq $t2, $s0, store_float
    
    lw $s0, 16($sp)          # Load "\n"
    beq $t2, $s0, store_float
    
    # Convert ASCII to digit and add to $f12
    sub $t3, $t2, 48
    
    # Check if we are in the decimal part
    beqz $t4, decimal_addition

    # Integer part processing
    mtc1 $t3, $f0           # Move integer to float register
    cvt.s.w $f0, $f0        # Convert to single-precision float
    mul.s $f12, $f12, $f1   # Multiply $f12 by 10.0
    add.s $f12, $f12, $f0   # Add new digit to $f12
    j next_char

decimal_addition:
    # Decimal part processing
    mtc1 $t3, $f0           # Move integer to float register
    cvt.s.w $f0, $f0        # Convert to single-precision float
    mul.s $f0, $f0, $f3     # Multiply digit by current decimal place factor
    add.s $f12, $f12, $f0   # Add to $f12
    mul.s $f3, $f3, $f2     # Update decimal factor (f3 *= 0.1)
    j next_char

decimal_part:
    li $t4, 0               # Decimal flag
    j next_char

next_char:
    addi $t0, $t0, 1        # Move to next character
    j parse_digits

store_float:    
    beq $t6, $zero, skip_negate
    neg.s $f12, $f12        # Negate if negative
    
skip_negate:
    swc1 $f12, 0($t1)       # Store the float
    addi $t1, $t1, 4
    # Reset decimal factor
    la $a0, float_val2
    l.s $f3, 0($a0)
    
    j skip_space

set_negative:
    li $t6, 1               # Set negative flag
    addi $t0, $t0, 1        # Move to next char
    j parse_digits

skip_space:        
    addi $t0, $t0, 1
    lw $s0, 8($sp)
    beq $s0, $t0, skip_space
    j parse_loop

end_parse:
	addi $t0, $t0, 1
	lb $t2, 0($t0)
	#Skip all these characters
    	lw $s0, 16($sp)          # Load "\n"
	beq $t2, $s0, end_parse
	lw $s0, 12($sp)          # Load "\r"
	beq $t2, $s0, end_parse
	lw $s0, 8($sp)          # Load " "
	beq $t2, $s0, end_parse
	
	#$t0 now points to the 3rd row
	#$t1: kernel
	la $t1, kernel
parse_loop2:
    lb $t2, 0($t0)          # Load the current character from fileWords
    
    # Compare with space
    lw $s0, 8($sp)         # Load " "
    beq $t2, $s0, skip_space2
    
    # Compare with "\r"
    lw $s0, 12($sp)         # Load "\r"
    beq $t2, $s0, end_parse2
    
    # Compare with "\n"
    lw $s0, 16($sp)          # Load "\n"
    beq $t2, $s0, end_parse2
    
    # Initialize registers for parsing a float
    li $t4, 1               # Flag for decimal part
    li $t5, 1               # Multiplier for decimal places
    li $t6, 0               # Sign flag (0 = positive, 1 = negative)
    mtc1 $zero, $f12        # Clear $f12 float register
    
    # Check if the number is negative
    lw $s0, 4($sp)          # Load "-"
    beq $t2, $s0, set_negative2
    
parse_digits2:
    lb $t2, 0($t0)
    beq $t2, 0, store_float2	# "\0"
    # Compare with "."
    lw $s0, 0($sp)          # Load "."
    beq $t2, $s0, decimal_part2
    
    # Check if we should store the float
    lw $s0, 8($sp)         # Load " "
    beq $t2, $s0, store_float2
    
    lw $s0, 12($sp)         # Load "\r"
    beq $t2, $s0, store_float2
    
    lw $s0, 16($sp)          # Load "\n"
    beq $t2, $s0, store_float2
    
    # Convert ASCII to digit and add to $f12
    sub $t3, $t2, 48
    
    # Check if we are in the decimal part
    beqz $t4, decimal_addition2

    # Integer part processing
    mtc1 $t3, $f0           # Move integer to float register
    cvt.s.w $f0, $f0        # Convert to single-precision float
    mul.s $f12, $f12, $f1   # Multiply $f12 by 10.0
    add.s $f12, $f12, $f0   # Add new digit to $f12
    j next_char2

decimal_addition2:
    # Decimal part processing
    mtc1 $t3, $f0           # Move integer to float register
    cvt.s.w $f0, $f0        # Convert to single-precision float
    mul.s $f0, $f0, $f3     # Multiply digit by current decimal place factor
    add.s $f12, $f12, $f0   # Add to $f12
    mul.s $f3, $f3, $f2     # Update decimal factor (f3 *= 0.1)
    j next_char2

decimal_part2:
    li $t4, 0               # Decimal flag
    j next_char2

next_char2:
    addi $t0, $t0, 1        # Move to next character
    j parse_digits2

store_float2:    
    beq $t6, $zero, skip_negate2
    neg.s $f12, $f12        # Negate if negative
    
skip_negate2:
    swc1 $f12, 0($t1)       # Store the float
    
    addi $t1, $t1, 4
    # Reset decimal factor
    la $a0, float_val2
    l.s $f3, 0($a0)
    
    j skip_space2

set_negative2:
    li $t6, 1               # Set negative flag
    addi $t0, $t0, 1        # Move to next char
    j parse_digits2

skip_space2:        
    addi $t0, $t0, 1
    lb $t2, 0($t0)
    beq $t2, 0, end_parse2	# "\0"
    lw $s0, 8($sp)
    beq $s0, $t0, skip_space2
    j parse_loop2

end_parse2:
	
padding:
    la $s0, paddedMatrix    # Address of paddedMatrix
    la $s1, image     # Address of image
    lw $t0, 32($sp)         # Load N (size of original image matrix)
    lw $t1, 24($sp)         # Load p (padding size)
    
    add $t2, $t0, $t1       # t2 = N + p
    add $t2, $t2, $t1       # t2 = N + 2p (padded size)

    mul $t3, $t2, $t2       # t3 = (N + 2p) * (N + 2p) (total number of elements in padded matrix)

    # Initialize paddedMatrix with zeros
    li $t4, 0               # Zero value
    move $t5, $s0           # Pointer to paddedMatrix
init_loop:
    beqz $t3, copy_loop    # If all elements are initialized, move to copy
    sw $t4, 0($t5)          # Store zero in paddedMatrix
    addi $t5, $t5, 4        # Move to the next element
    subi $t3, $t3, 1        # Decrement element counter
    j init_loop             # Repeat
copy_loop:
    mul $t6, $t2, $t1       # Calculate offset for padded rows (p * paddedSize)
    add $t6, $t6, $t1       # Add p to account for left padding
    mul $t6, $t6, 4         # Convert to byte offset (4 bytes per float)
    add $s2, $s0, $t6       # s2 = paddedMatrix start position for copying
    li $t7, 0               # Row counter
row_loop:
    beq $t7, $t0, end_padding  # If all rows are copied, finish
    li $t8, 0               # Column counter    
col_loop:
    beq $t8, $t0, next_row  # If all columns are copied, move to next row
    lwc1 $f0, 0($s1)        # Load a float from image
    swc1 $f0, 0($s2)        # Store the float in paddedMatrix
    addi $s1, $s1, 4        # Move to next element in image
    addi $s2, $s2, 4        # Move to next element in paddedMatrix
    addi $t8, $t8, 1        # Increment column counter
    j col_loop              # Repeat for the next column   
next_row:
    addi $t6, $t1, 0	    # Load p to $t6
    mul $t6, $t6, 8	    # Calculate offset
    add $s2, $s2, $t6
    addi $t7, $t7, 1        # Increment row counter
    j row_loop
# Print paddedMatrix in 2D form (row by row)
end_padding:
    # Skip printing
    j done_printing
    # Print a space between the numbers
    li $v0, 4               # print_string syscall code
    la $a0, newLine           # Print space separator
    syscall

    #lw $t0, 32($sp)         # Load N
    move $t0, $t2		# Load the size of padded matrix
    
    # Load the address of paddedMatrix
    la $t1, paddedMatrix    # Address of paddedMatrix

    # Outer loop to iterate through rows
    li $t2, 0               # Row counter, initialize to 0
print_rows:
    # Check if we have printed all rows
    bge $t2, $t0, done_printing

    # Inner loop to iterate through columns in the current row
    li $t3, 0               # Column counter, initialize to 0
    li $t4, 4               # Number of columns (change to fit your image size)
print_columns:
    # Load the float value from paddedMatrix
    lwc1 $f0, 0($t1)        # Load the current float element in the row
    # Print the float value
    li $v0, 2               # Syscall for printing float
    mov.s $f12, $f0         # Move float value to $f12 for printing
    syscall

    # Print space between numbers in the same row
    li $v0, 4               # Syscall for printing string
    la $a0, space           # Load address of space separator
    syscall

    # Move to next column (increment column index)
    addi $t1, $t1, 4        # Move to the next element in paddedMatrix
    addi $t3, $t3, 1        # Increment column counter
    blt $t3, $t0, print_columns  # Loop until all columns are printed

    # Print newline after completing a row
    li $v0, 4               # Syscall for printing string
    la $a0, newLine         # Load newline string
    syscall

    # Move to the next row (move address to next row in paddedMatrix)
    addi $t2, $t2, 1        # Increment row counter
    j print_rows            # Continue printing next row

done_printing:
	# Using $t0, $t1
    	# Cleanup the stack
    	addi $sp, $sp, 20
    	# Calculate output size
    	lw $s0, 12($sp) 	# N
    	lw $s1, 8($sp)		# M
    	lw $s2, 4($sp)		# p
    	lw $s3, 0($sp)		# s
    	
    	add $t0, $s0, $s2	# N + p
    	add $t0, $t0, $s2	# N + 2p
    	sub $t1, $t0, $s1	# N + 2p - M
    	div $t2, $t1, $s3	# (N + 2p - M)/s
    	addi $t2, $t2, 1	# ouput size
    	
    	bgt $s1, $t0, input_error	# M > N + 2p: input is invalid
    	addi $sp, $sp, -4
    	sw $t0, 0($sp)		# Store N + 2p
    	addi $sp, $sp, -4
    	sw $t1, 0($sp)		# Store N + 2p - m
    	addi $sp, $sp, -4
    	sw $t2, 0($sp)		# Store ouputsize   	
    	# Finished preparing 
    	# All registers are free
    	
cnn:
	# Preparing address
	la $s0, kernel	# addr of kernel
	la $s1, paddedMatrix	# addr of paddedMatrix
	la $s2, out	# addr of out
	
	lw $s3, 0($sp)		# output size
	lw $s4, 20($sp)		# M
	lw $s5, 4($sp)		# Ofset (N + 2p - M)
	
	# Using registers $s0 - $s5
	# Registers for loop: $t0, $t1, $t2, $t3, $t4
li $t0, 0	# Output row index (R)
cnn_outer_loop:
	# Check if all output rows are processed
	bge $t0, $s3, end_cnn
	li $t1, 0	# Output col index (C)
	cnn_inner_loop:
		bge $t1, $s3, cnn_next_row
		
		# Calculate start index for kernel
		# offset = s[(N + 2p).R + C]
		add $t4, $s5, $s4	# (N + 2p)
		mul $t4, $t4, $t0	# (N + 2p).R
		add $t4, $t4, $t1	# (N + 2p).R + C
		lw $s6, 12($sp)		# s
		mul $t4, $t4, $s6	# offset = s[(N + 2p).R + C]
		mul $t4, $t4, 4		# Convert to byte offset
		add $t4, $t4, $s1	# Add offset to base addr of poadded
		
		
		# Reset $s0 to store address of kernel
		la $s0, kernel
		mtc1 $zero, $f3		# Accumulator
		li $t2, 0		# krow index
		krow_loop:
			bge $t2, $s4, store_result
			li $t3, 0	# kcol index
			kcol_loop:
				bge $t3, $s4, next_krow
				# Load kernel element
				lwc1 $f0, 0($s0)
				addi $s0, $s0, 4	# next kernel element
				
				# Load padded element
				lwc1 $f1, 0($t4)
				addi $t4, $t4, 4
				
				# Multiply and accumulate
				mul.s $f2, $f0, $f1
				add.s $f3, $f3, $f2
				
				#li $v0, 2
				#mov.s $f12, $f1
				#syscall
				
				#li $v0, 4
				#la $a0, space
				#syscall
			
				
				addi $t3, $t3, 1	# Increase kcol index
				j kcol_loop
    			
			next_krow:
				#li $v0, 4
				#la $a0, newLine
				#syscall
				
				# Move padded element to next kernel row
				lw $s6, 4($sp)		# (N + 2p - M)
				mul $s6, $s6, 4		# *= 4 bytes
				add $t4, $t4, $s6
				
				addi $t2, $t2, 1	# Increase krow index
				j krow_loop
		store_result:	
			#li $v0, 4
			#la $a0, newLine
			#syscall
			
			# Store result
			swc1 $f3, 0($s2)
			addi $s2, $s2, 4	# Move to next output matrix pos
			
			addi $t1, $t1, 1	# Increase output column index
			j cnn_inner_loop	
	
	cnn_next_row:
		addi $t0, $t0, 1
		j cnn_outer_loop		
		
    	j exit
	
		
input_error:
	li $v0, 4
	la $a0, inputError
	syscall
	j exit
end_cnn:	
print_cnn_result:
	la $t1, out
	# Outer loop to iterate through rows
    	li $t2, 0               # Row counter, initialize to 0
result_print_rows:
    # Check if we have printed all rows
    bge $t2, $t0, result_done_printing

    # Inner loop to iterate through columns in the current row
    li $t3, 0               # Column counter, initialize to 0
    li $t4, 4               # Number of columns (change to fit your image size)
result_print_columns:
    # Load the float value from paddedMatrix
    lwc1 $f0, 0($t1)        # Load the current float element in the row
    # Print the float value
    li $v0, 2               # Syscall for printing float
    mov.s $f12, $f0         # Move float value to $f12 for printing
    syscall

    # Print space between numbers in the same row
    li $v0, 4               # Syscall for printing string
    la $a0, space           # Load address of space separator
    syscall

    # Move to next column (increment column index)
    addi $t1, $t1, 4        # Move to the next element in paddedMatrix
    addi $t3, $t3, 1        # Increment column counter
    blt $t3, $t0, result_print_columns  # Loop until all columns are printed

    # Print newline after completing a row
    li $v0, 4               # Syscall for printing string
    la $a0, newLine         # Load newline string
    syscall

    # Move to the next row (move address to next row in paddedMatrix)
    addi $t2, $t2, 1        # Increment row counter
    j result_print_rows            # Continue printing next row

result_done_printing:
exit:
    # Exit the program
    li $v0, 10
    syscall

